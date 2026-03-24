CREATE OR REPLACE PROCEDURE UDP_CopyPolicy (
    p_source_schema   IN VARCHAR2,
    p_target_schema   IN VARCHAR2,
    p_policy_numbers  IN VARCHAR2
)
AS
    -- Variable declaration

    v_existing_audit_record_count INTEGER;
    v_prev_batch_number           INTEGER;
    v_curr_batch_number           INTEGER;
    v_current_date                DATE;
    v_copy_status                 VARCHAR2(20);
    v_copy_quality                VARCHAR2(20) := NULL;
    v_issues_in_tables            VARCHAR2(4000) := NULL;
    v_copy_start_ts               TIMESTAMP;
    v_copy_end_ts                 TIMESTAMP;
    v_duration                    VARCHAR2(30);
    v_interval                    INTERVAL DAY TO SECOND;
    v_hours                       NUMBER;
    v_minutes                     NUMBER;
    v_seconds                     NUMBER;
    v_user                        VARCHAR2(30);
    v_audit_id                    VARCHAR2(40);
    v_client_to_primary_company_role_count INTEGER := 0;
    v_client_to_primary_company   VARCHAR2(40);
    v_db_link                     VARCHAR2(40);
    v_sql                         VARCHAR2(32767);

    -- NEW: safe schema identifiers used in dynamic SQL
    v_src_schema  VARCHAR2(128);
    v_tgt_schema  VARCHAR2(128);

    -- Cursors
    TYPE refcur IS REF CURSOR;
    v_policy_cur  refcur;         -- outer (policies)
    v_role_cur    refcur;         -- inner (roles)

    -- Outer policy row
    v_policy_guid VARCHAR2(40);
    v_policy_num  VARCHAR2(60);

    -- Record for dynamic role fetch
    TYPE t_role_rec IS RECORD (
        RoleGUID     VARCHAR2(40),
        ClientGUID   VARCHAR2(40),
        CompanyGUID  VARCHAR2(40)
    );
    v_role_rec t_role_rec;

    ----------------------------------------------------------------------------
    -- Autonomous, idempotent audit logger with dynamic target schema
    ----------------------------------------------------------------------------
    PROCEDURE log_audit_autonomous (
        p_target_schema IN VARCHAR2,
        p_audit_id      IN VARCHAR2,
        p_batch_no      IN INTEGER,
        p_policy_num    IN VARCHAR2,
        p_policy_guid   IN VARCHAR2,
        p_proc_date     IN DATE,
        p_status        IN VARCHAR2,
        p_quality       IN VARCHAR2,
        p_issues        IN VARCHAR2,
        p_start_ts      IN TIMESTAMP,
        p_end_ts        IN TIMESTAMP,
        p_duration      IN VARCHAR2,
        p_user          IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_sql_audit CLOB;
    BEGIN
        -- MERGE makes the audit write idempotent, avoiding ORA-00001 on retries.
        v_sql_audit :=
            'MERGE INTO ' || DBMS_ASSERT.SCHEMA_NAME(p_target_schema) || '.UDT_PolicyCopyAudit a ' ||
            'USING (SELECT :1 AS audit_id, :2 AS batchnumber, :3 AS policynumber, :4 AS policyguid, ' ||
            '              :5 AS processdate, :6 AS copystatus, :7 AS copyquality, :8 AS impactedtables, ' ||
            '              :9 AS copystartgmt, :10 AS copyendgmt, :11 AS duration, :12 AS processby ' ||
            '       FROM dual) s ' ||
            'ON (a.auditid = s.audit_id) ' ||
            'WHEN NOT MATCHED THEN ' ||
            '  INSERT (auditid, batchnumber, policynumber, policyguid, processdate, ' ||
            '          copystatus, copyquality, impactedtables, copystartgmt, copyendgmt, duration, processby) ' ||
            '  VALUES (s.audit_id, s.batchnumber, s.policynumber, s.policyguid, s.processdate, ' ||
            '          s.copystatus, s.copyquality, s.impactedtables, s.copystartgmt, s.copyendgmt, s.duration, s.processby) ' ||
            'WHEN MATCHED THEN ' ||
            '  UPDATE SET a.copystatus     = s.copystatus, ' ||
            '             a.copyquality    = s.copyquality, ' ||
            '             a.impactedtables = s.impactedtables, ' ||
            '             a.copystartgmt   = s.copystartgmt, ' ||
            '             a.copyendgmt     = s.copyendgmt, ' ||
            '             a.duration       = s.duration, ' ||
            '             a.processby      = s.processby';

        EXECUTE IMMEDIATE v_sql_audit
            USING p_audit_id, p_batch_no, p_policy_num, p_policy_guid,
                  p_proc_date, p_status, p_quality, p_issues,
                  p_start_ts, p_end_ts, p_duration, p_user;
        COMMIT; -- commit audit only, independent of main transaction
    END;
BEGIN
    -- Validate schema identifiers once to safely concatenate into dynamic SQL
	v_src_schema := DBMS_ASSERT.SIMPLE_SQL_NAME(p_source_schema);       -- Validate source schema (remote) by syntax only
	v_tgt_schema := DBMS_ASSERT.SCHEMA_NAME(p_target_schema);           -- Validate target schema (local) by existence
	

	-- Uppercasing identifiers: This matches dictionary norms and avoids case-sensitivity issues if someone ever passed a mixed‑case schema name
	v_src_schema := UPPER(v_src_schema);
	v_tgt_schema := UPPER(v_tgt_schema);


    -- Identify the DB Link to be used
	SELECT  MV.TextValue INTO v_db_link
	FROM AsMapGroup MG
	JOIN AsMapValue MV ON MV.MapGroupGUID = MG.MapGroupGUID
	JOIN AsMapCriteria MC1 ON MC1.MapValueGUID = MV.MapValueGUID AND MC1.MapCriteriaName = 'SourceDatabaseSchema'
	JOIN AsMapCriteria MC2 ON MC2.MapValueGUID = MV.MapValueGUID AND MC2.MapCriteriaName = 'TargetDatabaseSchema'
	WHERE MG.MapGroupDescription = 'SourceToTargetDBLinkDetails'
	AND MC1.TextValue = v_src_schema
	AND MC2.TextValue = v_tgt_schema
	;

	--Early reachability probe: Run a 0‑row query to fail fast if the link or schema is incorrect
	EXECUTE IMMEDIATE 'SELECT 1 FROM '|| v_src_schema ||'.AsPolicy@'|| v_db_link ||' WHERE 1=0';

    -- Get the current DB-user
    SELECT USER INTO v_user FROM dual;

    -- Fetch today's calendar date
    SELECT TRUNC(SYSDATE) INTO v_current_date FROM dual;

    -- Determine BatchNumber for current-run
    v_sql := 'SELECT (COALESCE(MAX(BatchNumber),0)+1) FROM ' || v_tgt_schema ||
             '.UDT_PolicyCopyAudit WHERE ProcessDate = :1';
    EXECUTE IMMEDIATE v_sql INTO v_curr_batch_number USING v_current_date;

    -- Clear existing entries in the Global Temporary Table
    v_sql := 'DELETE FROM ' || v_tgt_schema || '.GTT_Policy_To_Copy_Preserve_Records';
    EXECUTE IMMEDIATE v_sql;

    -- Populate GTT with policies to copy
    v_sql := 'INSERT INTO ' || v_tgt_schema || '.GTT_Policy_To_Copy_Preserve_Records (PolicyNumber, PolicyGUID)
              SELECT ExtractedPoliciesFromCommaSeparatedString.PolicyNumber, PoliciesFromSource.PolicyGUID
              FROM (
                  SELECT TRIM(REGEXP_SUBSTR(:1, ''[^,]+'', 1, LEVEL)) AS PolicyNumber
                  FROM dual
                  CONNECT BY LEVEL <= REGEXP_COUNT(:2, '','') + 1
              ) ExtractedPoliciesFromCommaSeparatedString
              JOIN ' || v_src_schema || '.AsPolicy@' || v_db_link || ' PoliciesFromSource
                ON PoliciesFromSource.PolicyNumber = ExtractedPoliciesFromCommaSeparatedString.PolicyNumber';
    EXECUTE IMMEDIATE v_sql USING p_policy_numbers, p_policy_numbers;

    -- Outer loop (cursor-based): iterate over policies in GTT
    OPEN v_policy_cur FOR
        'SELECT PolicyGUID, PolicyNumber FROM ' || v_tgt_schema || '.GTT_Policy_To_Copy_Preserve_Records';

    LOOP
        FETCH v_policy_cur INTO v_policy_guid, v_policy_num;
        EXIT WHEN v_policy_cur%NOTFOUND;

        BEGIN
            -- Capture policy copy process start timestamp
            SELECT SYSTIMESTAMP INTO v_copy_start_ts FROM dual;

            -- Create new AuditID
            SELECT NewID() INTO v_audit_id FROM dual;

            /* DBMS_OUTPUT.PUT_LINE('Starting copy for Policy: ' || v_policy_num || ' [' || v_policy_guid || ']...'); */

--oxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx[COPY DATA INTO TABLES START]xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxo--

--01. AsPolicy
            /* DBMS_OUTPUT.PUT_LINE(' AsPolicy'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsPolicy
                      WHERE PolicyGUID = :1';
            EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

            v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsPolicy (
                          PolicyGUID, PolicyNumber, PolicyName, CreationDate, IssueStateCode, PlanDate,
                          StatusCode, CompanyGUID, PlanGUID, XMLData, UpdatedGMT, SystemCode
                      )
                      SELECT
                          PolicyGUID, PolicyNumber, PolicyName, CreationDate, IssueStateCode, PlanDate,
                          StatusCode, CompanyGUID, PlanGUID, XMLData, UpdatedGMT, SystemCode
                      FROM ' || v_src_schema || '.AsPolicy@' || v_db_link ||
                      ' WHERE PolicyGUID = :1';
            EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--02. AsPolicyField
            /* DBMS_OUTPUT.PUT_LINE(' AsPolicyField'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsPolicyField
                      WHERE PolicyGUID  = :1';
            EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

            v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsPolicyField (
                          PolicyGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                          IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
                      )
                      SELECT
                          PolicyGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                          IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
                      FROM ' || v_src_schema || '.AsPolicyField@' || v_db_link ||
                      ' WHERE PolicyGUID = :1';
            EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--03. AsPolicyMultivalueField
            /* DBMS_OUTPUT.PUT_LINE(' AsPolicyMultivalueField'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsPolicyMultivalueField
            WHERE PolicyGUID  = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsPolicyMultivalueField (
                PolicyGUID, FieldName, FieldIndex, FieldTypeCode, DateValue,
                TextValue, IntValue, FloatValue, OptionTextFlag, OptionText,
                CurrencyCode, BigTextValue, GroupName
            )
            SELECT
                PolicyGUID, FieldName, FieldIndex, FieldTypeCode, DateValue,
                TextValue, IntValue, FloatValue, OptionTextFlag, OptionText,
                CurrencyCode, BigTextValue, GroupName
            FROM ' || v_src_schema || '.AsPolicyMultivalueField@' || v_db_link ||
            ' WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */


--04. AsSegment
            /* DBMS_OUTPUT.PUT_LINE(' AsSegment'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsSegment
                      WHERE PolicyGUID = :1';
            EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

            v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsSegment (
                          SegmentGUID, ParentSegmentGUID, PolicyGUID, SegmentNameGUID,
                          StatusCode, EffectiveDate, XMLData, PlanSegmentNameGUID
                      )
                      SELECT
                          SegmentGUID, ParentSegmentGUID, PolicyGUID, SegmentNameGUID,
                          StatusCode, EffectiveDate, XMLData, PlanSegmentNameGUID
                      FROM ' || v_src_schema || '.AsSegment@' || v_db_link ||
                      ' WHERE PolicyGUID = :1';
            EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--05. AsSegmentField
            /* DBMS_OUTPUT.PUT_LINE(' AsSegmentField');  */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsSegmentField
            WHERE SegmentGUID IN (
				SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsSegmentField (
                SegmentGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            )
            SELECT
                SegmentGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            FROM ' || v_src_schema || '.AsSegmentField@' || v_db_link ||
            ' WHERE SegmentGUID IN (
				SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--06. AsSegmentMultivalueField
            /* DBMS_OUTPUT.PUT_LINE(' AsSegmentMultivalueField');  */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsSegmentMultivalueField
            WHERE SegmentGUID IN (
				SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsSegmentMultivalueField (
                SegmentGUID, FieldName, FieldIndex, FieldTypeCode, DateValue,
                TextValue, IntValue, FloatValue, OptionTextFlag, OptionText,
                CurrencyCode, BigTextValue, GroupName
            )			
            SELECT
                SegmentGUID, FieldName, FieldIndex, FieldTypeCode, DateValue,
                TextValue, IntValue, FloatValue, OptionTextFlag, OptionText,
                CurrencyCode, BigTextValue, GroupName
            FROM ' || v_src_schema || '.AsSegmentMultivalueField@' || v_db_link ||
            ' WHERE SegmentGUID IN (
				SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :1
			)';			
			
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--07. AsRole
            /* DBMS_OUTPUT.PUT_LINE(' AsRole'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsRole
            WHERE RoleGUID IN (
				SELECT RoleGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
				UNION ALL
				SELECT RoleGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsRole (
                RoleGUID, CompanyGUID, PolicyGUID, SegmentGUID, ClientGUID, ExternalClientGUID,
                StateCode, RoleCode, PercentDollarCode, RolePercent, RoleAmount, XMLData, StatusCode
            )
            SELECT
                RoleGUID, CompanyGUID, PolicyGUID, SegmentGUID, ClientGUID, ExternalClientGUID,
                StateCode, RoleCode, PercentDollarCode, RolePercent, RoleAmount, XMLData, StatusCode
            FROM ' || v_src_schema || '.AsRole@' || v_db_link ||
			' WHERE RoleGUID IN (
				SELECT RoleGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
				UNION ALL
				SELECT RoleGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--08. AsRoleField
            /* DBMS_OUTPUT.PUT_LINE(' AsRoleField'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsRoleField
            WHERE RoleGUID IN (
				SELECT RoleGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
				UNION ALL
				SELECT RoleGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsRoleField (
                RoleGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            )
            SELECT
                RoleGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            FROM ' || v_src_schema || '.AsRoleField@' || v_db_link ||
			' WHERE RoleGUID IN (
				SELECT RoleGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
				UNION ALL
				SELECT RoleGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
			)';
            EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--09. AsRoleMultiValueField
            /* DBMS_OUTPUT.PUT_LINE(' AsRoleMultiValueField'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsRoleMultiValueField
            WHERE RoleGUID IN (
				SELECT RoleGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
				UNION ALL
				SELECT RoleGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsRoleMultiValueField (
                RoleGUID, FieldName, FieldIndex, FieldTypeCode, DateValue,
                TextValue, IntValue, FloatValue, OptionTextFlag, OptionText,
                CurrencyCode, BigTextValue, GroupName
            )
            SELECT
                RoleGUID, FieldName, FieldIndex, FieldTypeCode, DateValue,
                TextValue, IntValue, FloatValue, OptionTextFlag, OptionText,
                CurrencyCode, BigTextValue, GroupName
            FROM ' || v_src_schema || '.AsRoleMultiValueField@' || v_db_link ||
			' WHERE RoleGUID IN (
				SELECT RoleGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
				UNION ALL
				SELECT RoleGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--10. AsActivity
            /* DBMS_OUTPUT.PUT_LINE(' AsActivity'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsActivity
            WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsActivity (
                ActivityGUID, TransactionGUID, TypeCode, StatusCode, EffectiveDate, ActiveFromDate, ActiveToDate, ClientNumber, PolicyGUID, RelatedGUID, XMLData,
                ProcessingOrder, ErrorStatusCode, SuspenseStatusCode, ActivityGMT, EntryGMT, CreationGMT, ScheduleGUID, SubStatusCode, OriginalActivityGUID
            )
            SELECT
                ActivityGUID, TransactionGUID, TypeCode, StatusCode, EffectiveDate, ActiveFromDate, ActiveToDate, ClientNumber, PolicyGUID, RelatedGUID, XMLData,
                ProcessingOrder, ErrorStatusCode, SuspenseStatusCode, ActivityGMT, EntryGMT, CreationGMT, ScheduleGUID, SubStatusCode, OriginalActivityGUID
            FROM ' || v_src_schema || '.AsActivity@' || v_db_link ||
            ' WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--11. AsActivityField
            /* DBMS_OUTPUT.PUT_LINE(' AsActivityField'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsActivityField
            WHERE ActivityGUID IN (
				SELECT ActivityGUID FROM ' || v_tgt_schema || '.AsActivity WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsActivityField (
                ActivityGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            )
            SELECT
                ActivityGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            FROM ' || v_src_schema || '.AsActivityField@' || v_db_link ||
            ' WHERE ActivityGUID IN (
				SELECT ActivityGUID FROM ' || v_src_schema || '.AsActivity@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--12. AsActivityMultiValueField
            /* DBMS_OUTPUT.PUT_LINE(' AsActivityMultiValueField'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsActivityMultiValueField
            WHERE ActivityGUID IN (
				SELECT ActivityGUID FROM ' || v_tgt_schema || '.AsActivity WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsActivityMultiValueField (
                ActivityGUID, FieldName, FieldIndex, FieldTypeCode, DateValue,
                TextValue, IntValue, FloatValue, OptionTextFlag, OptionText,
                CurrencyCode, BigTextValue, GroupName
            )
            SELECT
                ActivityGUID, FieldName, FieldIndex, FieldTypeCode, DateValue,
                TextValue, IntValue, FloatValue, OptionTextFlag, OptionText,
                CurrencyCode, BigTextValue, GroupName
            FROM ' || v_src_schema || '.AsActivityMultiValueField@' || v_db_link ||
            ' WHERE ActivityGUID IN (
				SELECT ActivityGUID FROM ' || v_src_schema || '.AsActivity@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--13. AsActivityMath
            /* DBMS_OUTPUT.PUT_LINE(' AsActivityMath');  */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsActivityMath
            WHERE ActivityGUID IN (
				SELECT ActivityGUID FROM ' || v_tgt_schema || '.AsActivity WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsActivityMath (
                ActivityGUID, MathName, MathValue, CurrencyCode, SourceTypeCode
            )
            SELECT
                ActivityGUID, MathName, MathValue, CurrencyCode, SourceTypeCode
            FROM ' || v_src_schema || '.AsActivityMath@' || v_db_link ||
            ' WHERE ActivityGUID IN (
				SELECT ActivityGUID FROM ' || v_src_schema || '.AsActivity@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--14. AsActivitySpawn
            /* DBMS_OUTPUT.PUT_LINE(' AsActivitySpawn');  */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsActivitySpawn
            WHERE ActivityGUID IN (
				SELECT ActivityGUID FROM ' || v_tgt_schema || '.AsActivity WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsActivitySpawn (
                ActivityGUID, SpawnedByGUID
            )
            SELECT
                ActivityGUID, SpawnedByGUID
            FROM ' || v_src_schema || '.AsActivitySpawn@' || v_db_link ||
            ' WHERE ActivityGUID IN (
				SELECT ActivityGUID FROM ' || v_src_schema || '.AsActivity@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--15. AsSuspense
            /* DBMS_OUTPUT.PUT_LINE(' AsSuspense'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsSuspense
            WHERE PolicyNumber = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_num;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsSuspense (
                SuspenseGUID, SuspenseNumber, TypeCode, StatusCode, Amount, AttachedAmount, CompanyGUID, PolicyNumber, EffectiveDate, EffectiveFromDate,
                EffectiveToDate, ClientNumber, FirstName, LastName, AccountNumber, BankName, CheckNumber, XMLData, BatchNumber, CurrencyCode, UpdatedGMT
            )
            SELECT
                SuspenseGUID, SuspenseNumber, TypeCode, StatusCode, Amount, AttachedAmount, CompanyGUID, PolicyNumber, EffectiveDate, EffectiveFromDate,
                EffectiveToDate, ClientNumber, FirstName, LastName, AccountNumber, BankName, CheckNumber, XMLData, BatchNumber, CurrencyCode, UpdatedGMT
            FROM ' || v_src_schema || '.AsSuspense@' || v_db_link ||
            ' WHERE PolicyNumber = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_num;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--16. AsSuspenseField
            /* DBMS_OUTPUT.PUT_LINE(' AsSuspenseField'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsSuspenseField
            WHERE SuspenseGUID IN (
				SELECT SuspenseGUID FROM ' || v_tgt_schema || '.AsSuspense WHERE PolicyNumber = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_num;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsSuspenseField (
                SuspenseGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, CurrencyCode, OptionTextFlag, OptionText, BigTextValue
            )
            SELECT
                SuspenseGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, CurrencyCode, OptionTextFlag, OptionText, BigTextValue
            FROM ' || v_src_schema || '.AsSuspenseField@' || v_db_link ||
			' WHERE SuspenseGUID IN (
				SELECT SuspenseGUID FROM ' || v_src_schema || '.AsSuspense@' || v_db_link || ' WHERE PolicyNumber = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_num;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--17. AsActivitySuspense
            /* DBMS_OUTPUT.PUT_LINE(' AsActivitySuspense');  */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsActivitySuspense
            WHERE ActivityGUID IN (
				SELECT ActivityGUID FROM ' || v_tgt_schema || '.AsActivity WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsActivitySuspense (
                ActivityGUID, SuspenseGUID, SuspenseSequence, SpecifiedAmount, SystemGenerated, AttachedAmount
            )
            SELECT
                ActivityGUID, SuspenseGUID, SuspenseSequence, SpecifiedAmount, SystemGenerated, AttachedAmount
            FROM ' || v_src_schema || '.AsActivitySuspense@' || v_db_link ||
            ' WHERE ActivityGUID IN (
				SELECT ActivityGUID FROM ' || v_src_schema || '.AsActivity@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--18. EqPushEvent
            /* DBMS_OUTPUT.PUT_LINE(' EqPushEvent'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.EqPushEvent
            WHERE EntityType = ''POLICY'' AND RelatedGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.EqPushEvent (
                EventGUID, RelatedGUID, EntityType, EffectiveDate, ActivityGMT, ActivityGUID, EventName, EventMethod, MessageRequest,
				MessageResult, ReconciledDate, LastChangeTime, SendingServer, SendingThread, CombinedEntityGUID, MessageName
            )
            SELECT
                EventGUID, RelatedGUID, EntityType, EffectiveDate, ActivityGMT, ActivityGUID, EventName, EventMethod, MessageRequest,
				MessageResult, ReconciledDate, LastChangeTime, SendingServer, SendingThread, CombinedEntityGUID, MessageName
            FROM ' || v_src_schema || '.EqPushEvent@' || v_db_link ||
            ' WHERE EntityType = ''POLICY'' AND RelatedGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--19. EqPushError
            /* DBMS_OUTPUT.PUT_LINE(' EqPushError'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.EqPushError
            WHERE EntityType = ''POLICY'' AND RelatedGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.EqPushError (
                EventGUID, RelatedGUID, EntityType, EffectiveDate, ActivityGMT, ActivityGUID, EventName, EventMethod, MessageRequest, MessageError
            )
            SELECT
                EventGUID, RelatedGUID, EntityType, EffectiveDate, ActivityGMT, ActivityGUID, EventName, EventMethod, MessageRequest, MessageError
            FROM ' || v_src_schema || '.EqPushError@' || v_db_link ||
            ' WHERE EntityType = ''POLICY'' AND RelatedGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--20. AsClient
            /* DBMS_OUTPUT.PUT_LINE(' AsClient'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsClient
            WHERE ClientGUID IN (
				SELECT DISTINCT ClientGUID FROM (
					SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
					UNION ALL
					SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsClient (
                ClientGUID, TypeCode, CompanyName, LastName, FirstName, MiddleInitial, Prefix, Suffix, Sex, DateOfBirth, DateOfDeath, TaxID, Email,
				XMLData, UpdatedGMT, LegalResidenceCountryCode, Radio1, Radio2, Combo1, AlternateName1, AlternateName2, AlternateName3, AlternateName4,
				AlternateName5, AdditionalPrefix, AdditionalSuffix, TaxIDType, Title, MaritalStatus, BirthCountryCode, CitizenshipCountryCode,
				BirthRegionCode, PrimaryPhone, TextField1, TextField2, CheckBox1, CheckBox2, Combo2, Date1, Date2, EntityTypeCode, StatusCode
            )
            SELECT
                ClientGUID, TypeCode, CompanyName, LastName, FirstName, MiddleInitial, Prefix, Suffix, Sex, DateOfBirth, DateOfDeath, TaxID, Email,
				XMLData, UpdatedGMT, LegalResidenceCountryCode, Radio1, Radio2, Combo1, AlternateName1, AlternateName2, AlternateName3, AlternateName4,
				AlternateName5, AdditionalPrefix, AdditionalSuffix, TaxIDType, Title, MaritalStatus, BirthCountryCode, CitizenshipCountryCode,
				BirthRegionCode, PrimaryPhone, TextField1, TextField2, CheckBox1, CheckBox2, Combo2, Date1, Date2, EntityTypeCode, StatusCode
            FROM ' || v_src_schema || '.AsClient@' || v_db_link ||
			' WHERE ClientGUID IN (
				SELECT DISTINCT ClientGUID FROM (
					SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
					UNION ALL
					SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--21. AsClientField
            /* DBMS_OUTPUT.PUT_LINE(' AsClientField'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsClientField
            WHERE ClientGUID IN (
				SELECT DISTINCT ClientGUID FROM (
					SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
					UNION ALL
					SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsClientField (
                ClientGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            )
            SELECT
                ClientGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            FROM ' || v_src_schema || '.AsClientField@' || v_db_link ||
			' WHERE ClientGUID IN (
				SELECT DISTINCT ClientGUID FROM (
					SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
					UNION ALL
					SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--22. AsClientPhone
            /* DBMS_OUTPUT.PUT_LINE(' AsClientPhone'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsClientPhone
            WHERE ClientGUID IN (
				SELECT DISTINCT ClientGUID FROM (
					SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
					UNION ALL
					SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsClientPhone (
                PhoneNumberGUID, ClientGUID
            )
            SELECT
                PhoneNumberGUID, ClientGUID
            FROM ' || v_src_schema || '.AsClientPhone@' || v_db_link ||
			' WHERE ClientGUID IN (
				SELECT DISTINCT ClientGUID FROM (
					SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
					UNION ALL
					SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--23. AsPhone
            /* DBMS_OUTPUT.PUT_LINE(' AsPhone'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsPhone
            WHERE PhoneNumberGUID IN (
				(
					SELECT PhoneNumberGUID FROM ' || v_tgt_schema || '.AsClientPhone WHERE ClientGUID IN (
						SELECT DISTINCT ClientGUID FROM (
							SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
							UNION ALL
							SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
						)
					)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsPhone (
                PhoneNumberGUID, CountryCode, PhoneTypeCode, StatusCode, TypeCode, CallingCode, PhoneNumber, Extension, Preferred
            )
            SELECT
                PhoneNumberGUID, CountryCode, PhoneTypeCode, StatusCode, TypeCode, CallingCode, PhoneNumber, Extension, Preferred
            FROM ' || v_src_schema || '.AsPhone@' || v_db_link ||
			' WHERE PhoneNumberGUID IN (
				(
					SELECT PhoneNumberGUID FROM ' || v_src_schema || '.AsClientPhone@' || v_db_link || ' WHERE ClientGUID IN (
						SELECT DISTINCT ClientGUID FROM (
							SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
							UNION ALL
							SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
						)
					)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--24. AsAddressRole
            /* DBMS_OUTPUT.PUT_LINE(' AsAddressRole'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsAddressRole
            WHERE ClientGUID IN (
				SELECT DISTINCT ClientGUID FROM (
					SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
					UNION ALL
					SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsAddressRole (
                AddressRoleGUID, AddressRoleCode, ClientGUID, AddressGUID, DefaultFlag, EmailCorrespondenceFlag
            )
            SELECT
                AddressRoleGUID, AddressRoleCode, ClientGUID, AddressGUID, DefaultFlag, EmailCorrespondenceFlag
            FROM ' || v_src_schema || '.AsAddressRole@' || v_db_link ||
			' WHERE ClientGUID IN (
				SELECT DISTINCT ClientGUID FROM (
					SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
					UNION ALL
					SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--25. AsAddress
            /* DBMS_OUTPUT.PUT_LINE(' AsAddress'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsAddress
            WHERE AddressGUID IN (
				(
					SELECT AddressGUID FROM ' || v_tgt_schema || '.AsAddressRole WHERE ClientGUID IN (
						SELECT DISTINCT ClientGUID FROM (
							SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
							UNION ALL
							SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
						)
					)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsAddress (
                AddressGUID, AddressLine1, AddressLine2, AddressLine3, AddressLine4, City, StateCode, CountryCode, PostalID, Email, PhoneNumber,
				FaxNumber, XMLData, EffectiveDate, ExpirationDate, AddressLine5, AddressLine6, RegionCode, MunicipalityCode
            )
            SELECT
                AddressGUID, AddressLine1, AddressLine2, AddressLine3, AddressLine4, City, StateCode, CountryCode, PostalID, Email, PhoneNumber,
				FaxNumber, XMLData, EffectiveDate, ExpirationDate, AddressLine5, AddressLine6, RegionCode, MunicipalityCode
            FROM ' || v_src_schema || '.AsAddress@' || v_db_link ||
			' WHERE AddressGUID IN (
				(
					SELECT AddressGUID FROM ' || v_src_schema || '.AsAddressRole@' || v_db_link || ' WHERE ClientGUID IN (
						SELECT DISTINCT ClientGUID FROM (
							SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
							UNION ALL
							SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
						)
					)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--26. AsAddressField
            /* DBMS_OUTPUT.PUT_LINE(' AsAddressField'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsAddressField
            WHERE AddressGUID IN (
				(
					SELECT AddressGUID FROM ' || v_tgt_schema || '.AsAddressRole WHERE ClientGUID IN (
						SELECT DISTINCT ClientGUID FROM (
							SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
							UNION ALL
							SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
						)
					)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsAddressField (
                AddressGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            )
            SELECT
                AddressGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            FROM ' || v_src_schema || '.AsAddressField@' || v_db_link ||
			' WHERE AddressGUID IN (
				(
					SELECT AddressGUID FROM ' || v_src_schema || '.AsAddressRole@' || v_db_link || ' WHERE ClientGUID IN (
						SELECT DISTINCT ClientGUID FROM (
							SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
							UNION ALL
							SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
						)
					)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--27. AsBillDetail
            /* DBMS_OUTPUT.PUT_LINE(' AsBillDetail'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsBillDetail
            WHERE BillDetailGUID IN (
				SELECT BillDetailGUID FROM ' || v_tgt_schema || '.AsBillDetail WHERE BillEntityType = ''POLICY'' AND BillEntityGUID = :1
				UNION ALL
				SELECT BillDetailGUID FROM ' || v_tgt_schema || '.AsBillDetail WHERE BillEntityType = ''SEGMENT'' AND BillEntityGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsBillDetail (
                BillDetailGUID, OriginatingActivityGUID, BillEntityGUID, BillEntityType, BillDetailReferenceGUID,
				BillGroupGUID, BillGroupType, ReceivableDueType, Amount, CurrencyCode, Status, DueDate
            )
            SELECT
                BillDetailGUID, OriginatingActivityGUID, BillEntityGUID, BillEntityType, BillDetailReferenceGUID,
				BillGroupGUID, BillGroupType, ReceivableDueType, Amount, CurrencyCode, Status, DueDate
            FROM ' || v_src_schema || '.AsBillDetail@' || v_db_link ||
            ' WHERE BillDetailGUID IN (
				SELECT BillDetailGUID FROM ' || v_src_schema || '.AsBillDetail@' || v_db_link || ' WHERE BillEntityType = ''POLICY'' AND BillEntityGUID = :1
				UNION ALL
				SELECT BillDetailGUID FROM ' || v_src_schema || '.AsBillDetail@' || v_db_link || ' WHERE BillEntityType = ''SEGMENT'' AND BillEntityGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--28. AsBillDetailField
            /* DBMS_OUTPUT.PUT_LINE(' AsBillDetailField'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsBillDetailField
            WHERE BillDetailGUID IN (
				SELECT BillDetailGUID FROM ' || v_tgt_schema || '.AsBillDetail WHERE BillEntityType = ''POLICY'' AND BillEntityGUID = :1
				UNION ALL
				SELECT BillDetailGUID FROM ' || v_tgt_schema || '.AsBillDetail WHERE BillEntityType = ''SEGMENT'' AND BillEntityGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsBillDetailField (
				BillDetailGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            )
            SELECT
                BillDetailGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            FROM ' || v_src_schema || '.AsBillDetailField@' || v_db_link ||
            ' WHERE BillDetailGUID IN (
				SELECT BillDetailGUID FROM ' || v_src_schema || '.AsBillDetail@' || v_db_link || ' WHERE BillEntityType = ''POLICY'' AND BillEntityGUID = :1
				UNION ALL
				SELECT BillDetailGUID FROM ' || v_src_schema || '.AsBillDetail@' || v_db_link || ' WHERE BillEntityType = ''SEGMENT'' AND BillEntityGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--29. AsDisbursement
            /* DBMS_OUTPUT.PUT_LINE(' AsDisbursement'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsDisbursement
            WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsDisbursement (
                DisbursementGUID, PolicyGUID, RoleGUID, ActivityGUID, DisbursementNumber, DisbursementDate,
				DisbursementTypeCode, DisbursementStatusCode, DisbursementAmount, TaxableAmount, XMLData, CurrencyCode
            )
            SELECT
                DisbursementGUID, PolicyGUID, RoleGUID, ActivityGUID, DisbursementNumber, DisbursementDate,
				DisbursementTypeCode, DisbursementStatusCode, DisbursementAmount, TaxableAmount, XMLData, CurrencyCode
            FROM ' || v_src_schema || '.AsDisbursement@' || v_db_link ||
            ' WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--30. AsDisbursementField
            /* DBMS_OUTPUT.PUT_LINE(' AsDisbursementField');  */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsDisbursementField
            WHERE DisbursementGUID IN (
				SELECT DisbursementGUID FROM ' || v_tgt_schema || '.AsDisbursement WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsDisbursementField (
                DisbursementGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, CurrencyCode, OptionText, OptionTextFlag, BigTextValue
            )
            SELECT
                DisbursementGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, CurrencyCode, OptionText, OptionTextFlag, BigTextValue
            FROM ' || v_src_schema || '.AsDisbursementField@' || v_db_link ||
            ' WHERE DisbursementGUID IN (
				SELECT DisbursementGUID FROM ' || v_src_schema || '.AsDisbursement@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--31. AsDisbursementApproval
            /* DBMS_OUTPUT.PUT_LINE(' AsDisbursementApproval');  */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsDisbursementApproval
            WHERE DisbursementGUID IN (
				SELECT DisbursementGUID FROM ' || v_tgt_schema || '.AsDisbursement WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsDisbursementApproval (
                DisbursementApprovalGUID, DisbursementGUID, StatusCode, DisbursementDisapprovalCode, ClientNumber, XMLData, ApprovalDate
            )
            SELECT
                DisbursementApprovalGUID, DisbursementGUID, StatusCode, DisbursementDisapprovalCode, ClientNumber, XMLData, ApprovalDate
            FROM ' || v_src_schema || '.AsDisbursementApproval@' || v_db_link ||
            ' WHERE DisbursementGUID IN (
				SELECT DisbursementGUID FROM ' || v_src_schema || '.AsDisbursement@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--32. AsCasePolicy
            /* DBMS_OUTPUT.PUT_LINE(' AsCasePolicy'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsCasePolicy
            WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsCasePolicy (
                CaseGUID, PolicyGUID, RoleCode
            )
            SELECT
                CaseGUID, PolicyGUID, RoleCode
            FROM ' || v_src_schema || '.AsCasePolicy@' || v_db_link ||
            ' WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--33. AsCase
            /* DBMS_OUTPUT.PUT_LINE(' AsCase'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsCase
            WHERE CaseGUID IN (
				SELECT CaseGUID FROM ' || v_tgt_schema || '.AsCasePolicy WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsCase (
                CaseGUID, CompanyGUID, StatusCode, CaseName, CaseNumber, CreationDate, UpdatedGMT
            )
            SELECT
                CaseGUID, CompanyGUID, StatusCode, CaseName, CaseNumber, CreationDate, UpdatedGMT
            FROM ' || v_src_schema || '.AsCase@' || v_db_link ||
			' WHERE CaseGUID IN (
				SELECT CaseGUID FROM ' || v_src_schema || '.AsCasePolicy@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--34. AsCommissionDetail
            /* DBMS_OUTPUT.PUT_LINE(' AsCommissionDetail'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsCommissionDetail
            WHERE CommissionDetailGUID IN (
				SELECT CommissionDetailGUID FROM ' || v_tgt_schema || '.AsCommissionDetail WHERE EntityTypeCode = ''POLICY'' AND EntityGUID = :1
				UNION ALL
				SELECT CommissionDetailGUID FROM ' || v_tgt_schema || '.AsCommissionDetail WHERE EntityTypeCode = ''SEGMENT'' AND EntityGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsCommissionDetail (
                CommissionDetailGUID, EffectiveDate, TypeCode, EntityTypeCode, EntityGUID, SourceComponentTypeCode,
				Amount, CurrencyCode, ClientGUID, StatusCode, OriginatingActivityGUID, UpdatedGMT
            )
            SELECT
                CommissionDetailGUID, EffectiveDate, TypeCode, EntityTypeCode, EntityGUID, SourceComponentTypeCode,
				Amount, CurrencyCode, ClientGUID, StatusCode, OriginatingActivityGUID, UpdatedGMT
            FROM ' || v_src_schema || '.AsCommissionDetail@' || v_db_link ||
            ' WHERE CommissionDetailGUID IN (
				SELECT CommissionDetailGUID FROM ' || v_src_schema || '.AsCommissionDetail@' || v_db_link || ' WHERE EntityTypeCode = ''POLICY'' AND EntityGUID = :1
				UNION ALL
				SELECT CommissionDetailGUID FROM ' || v_src_schema || '.AsCommissionDetail@' || v_db_link || ' WHERE EntityTypeCode = ''SEGMENT'' AND EntityGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--35. AsCommissionDetailField
            /* DBMS_OUTPUT.PUT_LINE(' AsCommissionDetailField'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsCommissionDetailField
            WHERE CommissionDetailGUID IN (
				SELECT CommissionDetailGUID FROM ' || v_tgt_schema || '.AsCommissionDetail WHERE EntityTypeCode = ''POLICY'' AND EntityGUID = :1
				UNION ALL
				SELECT CommissionDetailGUID FROM ' || v_tgt_schema || '.AsCommissionDetail WHERE EntityTypeCode = ''SEGMENT'' AND EntityGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsCommissionDetailField (
                CommissionDetailGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            )
            SELECT
                CommissionDetailGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            FROM ' || v_src_schema || '.AsCommissionDetailField@' || v_db_link ||
            ' WHERE CommissionDetailGUID IN (
				SELECT CommissionDetailGUID FROM ' || v_src_schema || '.AsCommissionDetail@' || v_db_link || ' WHERE EntityTypeCode = ''POLICY'' AND EntityGUID = :1
				UNION ALL
				SELECT CommissionDetailGUID FROM ' || v_src_schema || '.AsCommissionDetail@' || v_db_link || ' WHERE EntityTypeCode = ''SEGMENT'' AND EntityGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--36. AsRequirementPolicy
            /* DBMS_OUTPUT.PUT_LINE(' AsRequirementPolicy'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsRequirementPolicy
            WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsRequirementPolicy (
                RequirementGUID, PolicyGUID
            )
            SELECT
                RequirementGUID, PolicyGUID
            FROM ' || v_src_schema || '.AsRequirementPolicy@' || v_db_link ||
            ' WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;

            /* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--37. AsRequirement
            /* DBMS_OUTPUT.PUT_LINE(' AsRequirement'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsRequirement
            WHERE RequirementGUID IN (
				SELECT RequirementGUID FROM ' || v_tgt_schema || '.AsRequirementPolicy WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsRequirement (
                RequirementGUID, RequirementDefinitionGUID, StatusCode, TypeCode, OpenDate, CloseDate, DueDate, ExpirationDate, LastModifiedGMT,
				LastModifiedBy, Message, PreviousStatusCode, Comments, CreatedBy, OverDueGMT, NextProcessGMT, LockedGMT, CreatedGMT
            )
            SELECT
                RequirementGUID, RequirementDefinitionGUID, StatusCode, TypeCode, OpenDate, CloseDate, DueDate, ExpirationDate, LastModifiedGMT,
				LastModifiedBy, Message, PreviousStatusCode, Comments, CreatedBy, OverDueGMT, NextProcessGMT, LockedGMT, CreatedGMT
            FROM ' || v_src_schema || '.AsRequirement@' || v_db_link ||
			' WHERE RequirementGUID IN (
				SELECT RequirementGUID FROM ' || v_src_schema || '.AsRequirementPolicy@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--38. AsRequirementField
            /* DBMS_OUTPUT.PUT_LINE(' AsRequirementField'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsRequirementField
            WHERE RequirementGUID IN (
				SELECT RequirementGUID FROM ' || v_tgt_schema || '.AsRequirementPolicy WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsRequirementField (
                RequirementGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            )
            SELECT
                RequirementGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode, BigTextValue
            FROM ' || v_src_schema || '.AsRequirementField@' || v_db_link ||
			' WHERE RequirementGUID IN (
				SELECT RequirementGUID FROM ' || v_src_schema || '.AsRequirementPolicy@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--39. AsMatchedRequirementResult
            /* DBMS_OUTPUT.PUT_LINE(' AsMatchedRequirementResult'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsMatchedRequirementResult
            WHERE RequirementGUID IN (
				SELECT RequirementGUID FROM ' || v_tgt_schema || '.AsRequirementPolicy WHERE PolicyGUID =:1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsMatchedRequirementResult (
                RequirementResultGUID, RequirementGUID
            )
            SELECT
                RequirementResultGUID, RequirementGUID
            FROM ' || v_src_schema || '.AsMatchedRequirementResult@' || v_db_link ||
			' WHERE RequirementGUID IN (
				SELECT RequirementGUID FROM ' || v_src_schema || '.AsRequirementPolicy@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--40. AsRequirementResult
            /* DBMS_OUTPUT.PUT_LINE(' AsRequirementResult'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsRequirementResult
			WHERE RequirementResultGUID IN (
				SELECT RequirementResultGUID FROM ' || v_tgt_schema || '.AsMatchedRequirementResult
				WHERE RequirementGUID IN (
					SELECT RequirementGUID FROM ' || v_tgt_schema || '.AsRequirementPolicy WHERE PolicyGUID = :1
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsRequirementResult (
                RequirementResultGUID, StatusCode, ReceivedGMT, UpdatedGMT, ResultText,
				DocumentGUID, FulfilledBy, LastName, FirstName, DateOfBirth, TaxID
            )
            SELECT
                RequirementResultGUID, StatusCode, ReceivedGMT, UpdatedGMT, ResultText,
				DocumentGUID, FulfilledBy, LastName, FirstName, DateOfBirth, TaxID
            FROM ' || v_src_schema || '.AsRequirementResult@' || v_db_link ||
			' WHERE RequirementResultGUID IN (
				SELECT RequirementResultGUID FROM ' || v_src_schema || '.AsMatchedRequirementResult@' || v_db_link ||
				' WHERE RequirementGUID IN (
					SELECT RequirementGUID FROM ' || v_src_schema || '.AsRequirementPolicy@' || v_db_link || ' WHERE PolicyGUID = :1
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--41. AsRequirementResultField
            /* DBMS_OUTPUT.PUT_LINE(' AsRequirementResultField'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsRequirementResultField
			WHERE RequirementResultGUID IN (
				SELECT RequirementResultGUID FROM ' || v_tgt_schema || '.AsMatchedRequirementResult
				WHERE RequirementGUID IN (
					SELECT RequirementGUID FROM ' || v_tgt_schema || '.AsRequirementPolicy WHERE PolicyGUID = :1
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsRequirementResultField (
                RequirementResultGUID, FieldName, FieldTypeCode, BigTextValue, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode
            )
            SELECT
                RequirementResultGUID, FieldName, FieldTypeCode, BigTextValue, DateValue, TextValue,
                IntValue, FloatValue, OptionTextFlag, OptionText, CurrencyCode
            FROM ' || v_src_schema || '.AsRequirementResultField@' || v_db_link ||
			' WHERE RequirementResultGUID IN (
				SELECT RequirementResultGUID FROM ' || v_src_schema || '.AsMatchedRequirementResult@' || v_db_link ||
				' WHERE RequirementGUID IN (
					SELECT RequirementGUID FROM ' || v_src_schema || '.AsRequirementPolicy@' || v_db_link || ' WHERE PolicyGUID = :1
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--42. AsRequirementResultType
            /* DBMS_OUTPUT.PUT_LINE(' AsRequirementResultType'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsRequirementResultType
			WHERE RequirementResultGUID IN (
				SELECT RequirementResultGUID FROM ' || v_tgt_schema || '.AsMatchedRequirementResult
				WHERE RequirementGUID IN (
					SELECT RequirementGUID FROM ' || v_tgt_schema || '.AsRequirementPolicy WHERE PolicyGUID = :1
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsRequirementResultType (
                RequirementResultTypeGUID, RequirementResultGUID, TypeCode
            )
            SELECT
                RequirementResultTypeGUID, RequirementResultGUID, TypeCode
            FROM ' || v_src_schema || '.AsRequirementResultType@' || v_db_link ||
			' WHERE RequirementResultGUID IN (
				SELECT RequirementResultGUID FROM ' || v_src_schema || '.AsMatchedRequirementResult@' || v_db_link ||
				' WHERE RequirementGUID IN (
					SELECT RequirementGUID FROM ' || v_src_schema || '.AsRequirementPolicy@' || v_db_link || ' WHERE PolicyGUID = :1
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--43. AsHistory
            /* DBMS_OUTPUT.PUT_LINE(' AsHistory'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsHistory
			WHERE HistoryGUID IN (
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''01'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
						UNION ALL
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''02'' AND RelatedGUID = :3
				UNION ALL
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''03'' AND RelatedGUID IN (
					SELECT SuspenseGUID FROM ' || v_tgt_schema || '.AsSuspense WHERE PolicyNumber = :4
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''04'' AND RelatedGUID IN (
					SELECT RequirementGUID FROM ' || v_tgt_schema || '.AsRequirement WHERE RequirementGUID IN (
						SELECT RequirementGUID FROM ' || v_tgt_schema || '.AsRequirementPolicy WHERE PolicyGUID = :5
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''05'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :6
						UNION ALL
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :7)
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''10'' AND RelatedGUID IN (
					SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :8
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid, v_policy_num, v_policy_guid, v_policy_guid, v_policy_guid, v_policy_guid;
			--HistoryTypeCode = '19' is not used as this entity (GroupCustomer) is not linked to any specific policy.
			/* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsHistory (
                HistoryGUID, RelatedGUID, HistoryTypeCode, OperationCode, EffectiveDate, ClientNumber, UpdatedGMT, XMLData, Details
            )
            SELECT
                HistoryGUID, RelatedGUID, HistoryTypeCode, OperationCode, EffectiveDate, ClientNumber, UpdatedGMT, XMLData, Details
            FROM ' || v_src_schema || '.AsHistory@' || v_db_link ||
			' WHERE HistoryGUID IN (
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''01'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
						UNION ALL
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''02'' AND RelatedGUID = :3
				UNION ALL
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''03'' AND RelatedGUID IN (
					SELECT SuspenseGUID FROM ' || v_src_schema || '.AsSuspense@' || v_db_link || ' WHERE PolicyNumber = :4
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''04'' AND RelatedGUID IN (
					SELECT RequirementGUID FROM ' || v_src_schema || '.AsRequirement@' || v_db_link || ' WHERE RequirementGUID IN (
						SELECT RequirementGUID FROM ' || v_src_schema || '.AsRequirementPolicy@' || v_db_link || ' WHERE PolicyGUID = :5
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''05'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :6
						UNION ALL
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :7)
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''10'' AND RelatedGUID IN (
					SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :8
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid, v_policy_num, v_policy_guid, v_policy_guid, v_policy_guid, v_policy_guid;
			--HistoryTypeCode = '19' is not used as this entity (GroupCustomer) is not linked to any specific policy.
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--44. AsHistoryDetail
            /* DBMS_OUTPUT.PUT_LINE(' AsHistoryDetail'); */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsHistoryDetail
			WHERE HistoryGUID IN (
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''01'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
						UNION ALL
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''02'' AND RelatedGUID = :3
				UNION ALL
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''03'' AND RelatedGUID IN (
					SELECT SuspenseGUID FROM ' || v_tgt_schema || '.AsSuspense WHERE PolicyNumber = :4
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_tgt_schema|| '.AsHistory WHERE HistoryTypeCode = ''04'' AND RelatedGUID IN (
					SELECT RequirementGUID FROM ' || v_tgt_schema || '.AsRequirement WHERE RequirementGUID IN (
						SELECT RequirementGUID FROM ' || v_tgt_schema || '.AsRequirementPolicy WHERE PolicyGUID = :5
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''05'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :6
						UNION ALL
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :7)
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_tgt_schema || '.AsHistory WHERE HistoryTypeCode = ''10'' AND RelatedGUID IN (
					SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :8
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid, v_policy_num, v_policy_guid, v_policy_guid, v_policy_guid, v_policy_guid;
			--HistoryTypeCode = '19' is not used as this entity (GroupCustomer) is not linked to any specific policy.
			/* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsHistoryDetail (
                HistoryGUID, FieldName, DataTypeCode, FromData, ToData, FromOptionText, ToOptionText, FromBigData, ToBigData
            )
            SELECT
                HistoryGUID, FieldName, DataTypeCode, FromData, ToData, FromOptionText, ToOptionText, FromBigData, ToBigData
            FROM ' || v_src_schema || '.AsHistoryDetail@' || v_db_link ||
			' WHERE HistoryGUID IN (
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''01'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
						UNION ALL
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''02'' AND RelatedGUID = :3
				UNION ALL
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''03'' AND RelatedGUID IN (
					SELECT SuspenseGUID FROM ' || v_src_schema || '.AsSuspense@' || v_db_link || ' WHERE PolicyNumber = :4
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''04'' AND RelatedGUID IN (
					SELECT RequirementGUID FROM ' || v_src_schema || '.AsRequirement@' || v_db_link || ' WHERE RequirementGUID IN (
						SELECT RequirementGUID FROM ' || v_src_schema || '.AsRequirementPolicy@' || v_db_link|| ' WHERE PolicyGUID = :5
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''05'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :6
						UNION ALL
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :7)
					)
				)
				UNION ALL
				SELECT HistoryGUID FROM ' || v_src_schema || '.AsHistory@' || v_db_link || ' WHERE HistoryTypeCode = ''10'' AND RelatedGUID IN (
					SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :8
				)

			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid, v_policy_num, v_policy_guid, v_policy_guid, v_policy_guid, v_policy_guid;
			--HistoryTypeCode = '19' is not used as this entity (GroupCustomer) is not linked to any specific policy.
            /* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--45. AsTag
            /* DBMS_OUTPUT.PUT_LINE(' AsTag'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsTag
			WHERE TagGUID IN (
				SELECT TagGUID FROM ' || v_tgt_schema || '.AsTag WHERE EntityType = ''Policy'' AND EntityGUID = :1
				UNION ALL
				SELECT TagGUID FROM ' || v_tgt_schema || '.AsTag WHERE EntityType = ''Client'' AND EntityGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :2
						UNION ALL
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM AsSegment WHERE PolicyGUID = :3)
					)
				)
				UNION ALL
				SELECT TagGUID FROM ' || v_tgt_schema || '.AsTag WHERE EntityType = ''Case'' AND EntityGUID IN (
					SELECT CaseGUID FROM ' || v_tgt_schema || '.AsCase
					WHERE CaseGUID IN (
						SELECT CaseGUID FROM ' || v_tgt_schema || '.AsCasePolicy WHERE PolicyGUID = :4
					)
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid, v_policy_guid;
			--EntityType = 'Customer' is not used as this entity (GroupCustomer) is not linked to any specific policy.
			/* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsTag (
                TagGUID, EntityType, EntityGUID, ClientNumber, EffectiveDate, Comments, StatusCode, ExpiryDate
            )
            SELECT
                TagGUID, EntityType, EntityGUID, ClientNumber, EffectiveDate, Comments, StatusCode, ExpiryDate
            FROM ' || v_src_schema || '.AsTag@' || v_db_link ||
			' WHERE TagGUID IN (
				SELECT TagGUID FROM ' || v_src_schema || '.AsTag@' || v_db_link || ' WHERE EntityType = ''Policy'' AND EntityGUID = :1
				UNION ALL
				SELECT TagGUID FROM ' || v_src_schema || '.AsTag@' || v_db_link || ' WHERE EntityType = ''Client'' AND EntityGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :2
						UNION ALL
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :3)
					)
				)
				UNION ALL
				SELECT TagGUID FROM ' || v_src_schema || '.AsTag@' || v_db_link || ' WHERE EntityType = ''Case'' AND EntityGUID IN (
					SELECT CaseGUID FROM ' || v_src_schema || '.AsCase@' || v_db_link ||
					' WHERE CaseGUID IN (
						SELECT CaseGUID FROM ' || v_src_schema || '.AsCasePolicy@' || v_db_link || ' WHERE PolicyGUID = :4
					)
				)

			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid, v_policy_guid;
			--EntityType = 'Customer' is not used as this entity (GroupCustomer) is not linked to any specific policy.
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--46. AsWithholding
            /* DBMS_OUTPUT.PUT_LINE(' AsWithholding'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsWithholding
			WHERE WithholdingGUID IN (
				SELECT WithholdingGUID FROM ' || v_tgt_schema || '.AsWithholding WHERE TypeCode = ''02'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
						UNION ALL
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
					)
				)
				UNION ALL
				SELECT WithholdingGUID FROM ' || v_tgt_schema || '.AsWithholding WHERE TypeCode = ''03'' AND RelatedGUID = :3
				UNION ALL
				SELECT WithholdingGUID FROM ' || v_tgt_schema || '.AsWithholding WHERE TypeCode = ''04'' AND RelatedGUID IN (
					SELECT ActivityGUID FROM ' || v_tgt_schema || '.AsActivity WHERE PolicyGUID = :4
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsWithholding (
                WithholdingGUID, TypeCode, RelatedGUID, XMLData
            )
            SELECT
                WithholdingGUID, TypeCode, RelatedGUID, XMLData
            FROM ' || v_src_schema || '.AsWithholding@' || v_db_link ||
			' WHERE WithholdingGUID IN (
				SELECT WithholdingGUID FROM ' || v_src_schema || '.AsWithholding@' || v_db_link || ' WHERE TypeCode = ''02'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
						UNION ALL
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
					)
				)
				UNION ALL
				SELECT WithholdingGUID FROM ' || v_src_schema || '.AsWithholding@' || v_db_link || ' WHERE TypeCode = ''03'' AND RelatedGUID = :3
				UNION ALL
				SELECT WithholdingGUID FROM ' || v_src_schema || '.AsWithholding@' || v_db_link || ' WHERE TypeCode = ''04'' AND RelatedGUID IN (
					SELECT ActivityGUID FROM ' || v_src_schema || '.AsActivity@' || v_db_link || ' WHERE PolicyGUID = :4
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--47. AsWithholdingField
            /* DBMS_OUTPUT.PUT_LINE(' AsWithholdingField');  */

			v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsWithholdingField
            WHERE WithholdingGUID IN (
				SELECT WithholdingGUID FROM ' || v_tgt_schema || '.AsWithholding WHERE TypeCode = ''02'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE PolicyGUID = :1
						UNION ALL
						SELECT ClientGUID FROM ' || v_tgt_schema || '.AsRole WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2)
					)
				)
				UNION ALL
				SELECT WithholdingGUID FROM ' || v_tgt_schema || '.AsWithholding WHERE TypeCode = ''03'' AND RelatedGUID = :3
				UNION ALL
				SELECT WithholdingGUID FROM ' || v_tgt_schema || '.AsWithholding WHERE TypeCode = ''04'' AND RelatedGUID IN (
					SELECT ActivityGUID FROM ' || v_tgt_schema || '.AsActivity WHERE PolicyGUID = :4
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsWithholdingField (
                WithholdingGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, CurrencyCode, OptionTextFlag, OptionText, BigTextValue
            )
            SELECT
                WithholdingGUID, FieldName, FieldTypeCode, DateValue, TextValue,
                IntValue, FloatValue, CurrencyCode, OptionTextFlag, OptionText, BigTextValue
            FROM ' || v_src_schema || '.AsWithholdingField@' || v_db_link ||
            ' WHERE WithholdingGUID IN (
				SELECT WithholdingGUID FROM ' || v_src_schema || '.AsWithholding@' || v_db_link || ' WHERE TypeCode = ''02'' AND RelatedGUID IN (
					SELECT DISTINCT ClientGUID FROM (
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
						UNION ALL
						SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2)
					)
				)
				UNION ALL
				SELECT WithholdingGUID FROM ' || v_src_schema || '.AsWithholding@' || v_db_link || ' WHERE TypeCode = ''03'' AND RelatedGUID = :3
				UNION ALL
				SELECT WithholdingGUID FROM ' || v_src_schema || '.AsWithholding@' || v_db_link || ' WHERE TypeCode = ''04'' AND RelatedGUID IN (
					SELECT ActivityGUID FROM ' || v_src_schema || '.AsActivity@' || v_db_link || ' WHERE PolicyGUID = :4
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--48. AsAllocation
            /* DBMS_OUTPUT.PUT_LINE(' AsAllocation'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsAllocation
			WHERE AllocationGUID IN (
				SELECT AllocationGUID FROM ' || v_tgt_schema || '.AsAllocation WHERE TypeCode IN (''02'', ''09'', ''10'', ''11'', ''13'', ''14'', ''15'', ''16'', ''61'') AND RelatedGUID = :1
				UNION ALL
				SELECT AllocationGUID FROM ' || v_tgt_schema || '.AsAllocation WHERE TypeCode IN (''05'') AND RelatedGUID IN (
					SELECT SegmentGUID FROM ' || v_tgt_schema || '.AsSegment WHERE PolicyGUID = :2
				)
				UNION ALL
				SELECT AllocationGUID FROM ' || v_tgt_schema || '.AsAllocation WHERE TypeCode IN (''03'', ''99'') AND RelatedGUID IN (
					SELECT ActivityGUID FROM ' || v_tgt_schema || '.AsActivity WHERE PolicyGUID = :3
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsAllocation (
                AllocationGUID, GroupGUID, TypeCode, RelatedGUID, FundGUID, AllocationMethodCode, AllocationPercent,
				AllocationAmount, AllocationUnits, PercentInAllocation, EffectiveDate, SubAllocationTypeCode, CurrencyCode
            )
            SELECT
                AllocationGUID, GroupGUID, TypeCode, RelatedGUID, FundGUID, AllocationMethodCode, AllocationPercent,
				AllocationAmount, AllocationUnits, PercentInAllocation, EffectiveDate, SubAllocationTypeCode, CurrencyCode
            FROM ' || v_src_schema || '.AsAllocation@' || v_db_link ||
			' WHERE AllocationGUID IN (
				SELECT AllocationGUID FROM ' || v_src_schema || '.AsAllocation@' || v_db_link || ' WHERE TypeCode IN (''02'', ''09'', ''10'', ''11'', ''13'', ''14'', ''15'', ''16'', ''61'') AND RelatedGUID = :1
				UNION ALL
				SELECT AllocationGUID FROM ' || v_src_schema || '.AsAllocation@' || v_db_link || ' WHERE TypeCode IN (''05'') AND RelatedGUID IN (
					SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2
				)
				UNION ALL
				SELECT AllocationGUID FROM ' || v_src_schema || '.AsAllocation@' || v_db_link || ' WHERE TypeCode IN (''03'', ''99'') AND RelatedGUID IN (
					SELECT ActivityGUID FROM ' || v_src_schema || '.AsActivity@' || v_db_link || ' WHERE PolicyGUID = :3
				)
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid, v_policy_guid, v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--49. AsCycle
            /* DBMS_OUTPUT.PUT_LINE(' AsCycle'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsCycle
            WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsCycle (
                CycleGUID, CycleDate, MachineName, TypeCode, PlanGUID, PolicyGUID,
				CycleStatusCode, CycleGMT, Thread, ClientGUID, CycleMemberID
            )
            SELECT
                CycleGUID, CycleDate, MachineName, TypeCode, PlanGUID, PolicyGUID,
				CycleStatusCode, CycleGMT, Thread, ClientGUID, CycleMemberID
            FROM ' || v_src_schema || '.AsCycle@' || v_db_link ||
            ' WHERE PolicyGUID = :1';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--50. AsCycleDetail
            /* DBMS_OUTPUT.PUT_LINE(' AsCycleDetail'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema || '.AsCycleDetail
            WHERE CycleGUID IN (
				SELECT CycleGUID FROM ' || v_tgt_schema || '.AsCycle WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsCycleDetail (
                CycleGUID, WorkItemGUID, ActivityGUID, StatusCode, CycleMemberID, CreationGMT, XMLData
            )
            SELECT
                CycleGUID, WorkItemGUID, ActivityGUID, StatusCode, CycleMemberID, CreationGMT, XMLData
            FROM ' || v_src_schema || '.AsCycleDetail@' || v_db_link ||
            ' WHERE CycleGUID IN (
				SELECT CycleGUID FROM ' || v_src_schema || '.AsCycle@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */

--51. AsCycleSequenceProcess
            /* DBMS_OUTPUT.PUT_LINE(' AsCycleSequenceProcess'); */

            v_sql := 'DELETE FROM ' || v_tgt_schema|| '.AsCycleSequenceProcess
            WHERE CycleGUID IN (
				SELECT CycleGUID FROM ' || v_tgt_schema || '.AsCycle WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
            /* DBMS_OUTPUT.PUT_LINE('  Deleted ' || SQL%ROWCOUNT || ' row(s)'); */

			v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsCycleSequenceProcess (
                CycleSequenceProcessGUID, CycleGUID, SequenceGUID, CycleTypeCode, LevelIndex, CycleStatusCode
            )
            SELECT
                CycleSequenceProcessGUID, CycleGUID, SequenceGUID, CycleTypeCode, LevelIndex, CycleStatusCode
            FROM ' || v_src_schema || '.AsCycleSequenceProcess@' || v_db_link ||
            ' WHERE CycleGUID IN (
				SELECT CycleGUID FROM ' || v_src_schema || '.AsCycle@' || v_db_link || ' WHERE PolicyGUID = :1
			)';
			EXECUTE IMMEDIATE v_sql USING v_policy_guid;
			/* DBMS_OUTPUT.PUT_LINE('  Inserted ' || SQL%ROWCOUNT || ' row(s)'); */


------------------------------------------Handling the RoleGUIDs with RoleCode=02------------------------------------------[START]

            /* DBMS_OUTPUT.PUT_LINE('-------------Client To Primary Company---------------------[START]'); */
            -- Ref Cursor for RoleCode = '02'
            v_sql := '
                SELECT RoleGUID, ClientGUID, CompanyGUID
                FROM ' || v_src_schema || '.AsRole@' || v_db_link || '
                WHERE RoleCode = ''02''
                  AND CompanyGUID IN (SELECT CompanyGUID FROM AsCompany WHERE CompanyName = ''iA'')
                  AND ClientGUID IN (
                    SELECT DISTINCT ClientGUID FROM (
                        SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE PolicyGUID = :1
                        UNION ALL
                        SELECT ClientGUID FROM ' || v_src_schema || '.AsRole@' || v_db_link || ' WHERE SegmentGUID IN (
                            SELECT SegmentGUID FROM ' || v_src_schema || '.AsSegment@' || v_db_link || ' WHERE PolicyGUID = :2
                        )
                    )
                )';

            OPEN v_role_cur FOR v_sql USING v_policy_guid, v_policy_guid;

            LOOP
                FETCH v_role_cur INTO v_role_rec;
                EXIT WHEN v_role_cur%NOTFOUND;

                -- Check if any role-record (with RoleCode=02) is present or not in TARGET.
                /* DBMS_OUTPUT.PUT_LINE('Checking RoleGUID: ' || v_role_rec.RoleGUID || ', ClientGUID: ' || v_role_rec.ClientGUID); */

                v_sql := 'SELECT COALESCE(COUNT(RoleGUID), 0)
                          FROM ' || v_tgt_schema || '.AsRole
                          WHERE RoleCode = ''02''
                            AND CompanyGUID IN (SELECT CompanyGUID FROM AsCompany WHERE CompanyName = ''iA'')
                            AND ClientGUID = :1';
                EXECUTE IMMEDIATE v_sql INTO v_client_to_primary_company_role_count USING v_role_rec.ClientGUID;

                IF v_client_to_primary_company_role_count = 0 THEN
                    -- Check if same RoleGUID exists in TARGET but with different ClientGUID
                    /* DBMS_OUTPUT.PUT_LINE('DebugCheckpoint-1'); */
                    v_sql := 'SELECT MIN(ClientGUID) FROM ' || v_tgt_schema || '.AsRole WHERE RoleGUID = :1';
                    EXECUTE IMMEDIATE v_sql INTO v_client_to_primary_company USING v_role_rec.RoleGUID;
                    /* DBMS_OUTPUT.PUT_LINE('v_client_to_primary_company: ' || v_client_to_primary_company); */
                    /* DBMS_OUTPUT.PUT_LINE('DebugCheckpoint-2'); */

                    IF v_client_to_primary_company != v_role_rec.ClientGUID THEN
                        -- Create new role-record (with RoleCode=02) in TARGET and link it with the SOURCE-ClientGUID
                        /* DBMS_OUTPUT.PUT_LINE('DebugCheckpoint-3'); */
                        v_sql := 'INSERT INTO ' || v_tgt_schema || '.AsRole (
                                      RoleGUID, CompanyGUID, PolicyGUID, SegmentGUID, ClientGUID, ExternalClientGUID,
                                      StateCode, RoleCode, PercentDollarCode, RolePercent, RoleAmount, XMLData, StatusCode
                                  )
                                  VALUES (
                                      NewID(), :1, NULL, NULL, :2, NULL,
                                      NULL, ''02'', NULL, NULL, NULL, NULL, ''01''
                                  )';
                        EXECUTE IMMEDIATE v_sql USING v_role_rec.CompanyGUID, v_role_rec.ClientGUID;
                        /* DBMS_OUTPUT.PUT_LINE('DebugCheckpoint-4'); */
                    ELSE
                        -- Insert the role-record (with RoleCode=02) as-is from SOURCE
                        /* DBMS_OUTPUT.PUT_LINE('DebugCheckpoint-5'); */
                        v_sql := '
                            INSERT INTO ' || v_tgt_schema || '.AsRole (
                                RoleGUID, CompanyGUID, PolicyGUID, SegmentGUID, ClientGUID, ExternalClientGUID,
                                StateCode, RoleCode, PercentDollarCode, RolePercent, RoleAmount, XMLData, StatusCode
                            )
                            SELECT
                                RoleGUID, CompanyGUID, PolicyGUID, SegmentGUID, ClientGUID, ExternalClientGUID,
                                StateCode, RoleCode, PercentDollarCode, RolePercent, RoleAmount, XMLData, StatusCode
                            FROM ' || v_src_schema || '.AsRole@' || v_db_link || '
                            WHERE RoleGUID = :1';

                        EXECUTE IMMEDIATE v_sql USING v_role_rec.RoleGUID;
                        /* DBMS_OUTPUT.PUT_LINE('DebugCheckpoint-6'); */
                    END IF;
                END IF;
            END LOOP;
            /* DBMS_OUTPUT.PUT_LINE('-------------Client To Primary Company---------------------[E N D]'); */
            IF v_role_cur%ISOPEN THEN
                CLOSE v_role_cur;
            END IF;

--oxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx[COPY DATA INTO TABLES E N D]xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxo--

            -- Capture policy copy process end timestamp
            SELECT SYSTIMESTAMP INTO v_copy_end_ts FROM dual;

            -- Calculate policy-copy duration [START]
            v_interval := v_copy_end_ts - v_copy_start_ts;
            /* DBMS_OUTPUT.PUT_LINE('v_interval: ' || v_interval); */

            v_hours   := EXTRACT(HOUR   FROM v_interval);
            v_minutes := EXTRACT(MINUTE FROM v_interval);
            v_seconds := FLOOR(EXTRACT(SECOND FROM v_interval)); -- round down

            -- Build formatted duration-string
            v_duration := '';
            IF v_hours > 0 THEN
                v_duration := v_duration || v_hours || ' hr';
            END IF;

            IF v_minutes > 0 THEN
                IF v_duration IS NOT NULL THEN
                    v_duration := v_duration || ' ';
                END IF;
                v_duration := v_duration || v_minutes || ' min';
            END IF;

            IF v_seconds > 0 THEN
                IF v_duration IS NOT NULL THEN
                    v_duration := v_duration || ' ';
                END IF;
                v_duration := v_duration || v_seconds || ' sec';
            END IF;

            -- Fallback for zero duration
            IF v_duration IS NULL THEN
                v_duration := '0 sec';
            END IF;
            -- Calculate policy-copy duration [E N D]

            v_copy_status := 'SUCCESS';

            -- Create Audit Entry for copy (autonomous + idempotent)
            log_audit_autonomous(
                p_target_schema => v_tgt_schema,
                p_audit_id      => v_audit_id,
                p_batch_no      => v_curr_batch_number,
                p_policy_num    => v_policy_num,
                p_policy_guid   => v_policy_guid,
                p_proc_date     => v_current_date,
                p_status        => v_copy_status,
                p_quality       => v_copy_quality,
                p_issues        => v_issues_in_tables,
                p_start_ts      => v_copy_start_ts,
                p_end_ts        => v_copy_end_ts,
                p_duration      => v_duration,
                p_user          => v_user
            );

            /* DBMS_OUTPUT.PUT_LINE('Finishing copy for Policy: ' || v_policy_num || ' [' || v_policy_guid || ']...<<Copy Duration: ' || v_duration || '>>'); */
            /* DBMS_OUTPUT.PUT_LINE('-----------------------------------'); */

            -- Per-policy commit: safe because inner cursor is already closed.
            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                -- Capture policy copy process exception timestamp
                DBMS_OUTPUT.PUT_LINE('X Error processing policy-copy: ' || v_policy_num || ' [' || v_policy_guid || '].');
                DBMS_OUTPUT.PUT_LINE('   Error message: ' || SQLERRM);

                -- Ensure inner cursor is closed on error
                IF v_role_cur%ISOPEN THEN
                    CLOSE v_role_cur;
                END IF;

                -- Roll back this policy   s uncommitted work
                ROLLBACK;

                SELECT SYSTIMESTAMP INTO v_copy_end_ts FROM dual;

                -- Calculate policy copy-attempt duration [START]
                v_interval := v_copy_end_ts - v_copy_start_ts;
                /* DBMS_OUTPUT.PUT_LINE('v_interval (exception): ' || v_interval); */

                v_hours   := EXTRACT(HOUR   FROM v_interval);
                v_minutes := EXTRACT(MINUTE FROM v_interval);
                v_seconds := FLOOR(EXTRACT(SECOND FROM v_interval)); -- round down

                v_duration := '';
                IF v_hours > 0 THEN v_duration := v_duration || v_hours || ' hr'; END IF;
                IF v_minutes > 0 THEN
                    IF v_duration IS NOT NULL THEN v_duration := v_duration || ' '; END IF;
                    v_duration := v_duration || v_minutes || ' min';
                END IF;
                IF v_seconds > 0 THEN
                    IF v_duration IS NOT NULL THEN v_duration := v_duration || ' '; END IF;
                    v_duration := v_duration || v_seconds || ' sec';
                END IF;
                IF v_duration IS NULL THEN v_duration := '0 sec'; END IF;
                -- Calculate policy copy-attempt duration [E N D]

                v_copy_status := 'FAILURE';

                -- Create Audit Entry for failed copy-attempt (autonomous + idempotent)
                log_audit_autonomous(
                    p_target_schema => v_tgt_schema,
                    p_audit_id      => v_audit_id,
                    p_batch_no      => v_curr_batch_number,
                    p_policy_num    => v_policy_num,
                    p_policy_guid   => v_policy_guid,
                    p_proc_date     => v_current_date,
                    p_status        => v_copy_status,
                    p_quality       => v_copy_quality,
                    p_issues        => v_issues_in_tables,
                    p_start_ts      => v_copy_start_ts,
                    p_end_ts        => v_copy_end_ts,
                    p_duration      => v_duration,
                    p_user          => v_user
                );
                -- Continue with next policy
        END;
    END LOOP;

    -- Close outer cursor
    IF v_policy_cur%ISOPEN THEN
        CLOSE v_policy_cur;
    END IF;

    -- Explicitly clear GTT at end of run (because we use PRESERVE ROWS to allow per-policy commits)
    v_sql := 'DELETE FROM ' || v_tgt_schema || '.GTT_Policy_To_Copy_Preserve_Records';
    EXECUTE IMMEDIATE v_sql;
    COMMIT;

 EXCEPTION
    WHEN OTHERS THEN
        -- Final safety net: close any open cursors and cleanup GTT
        IF v_role_cur%ISOPEN THEN
            CLOSE v_role_cur;
        END IF;
        IF v_policy_cur%ISOPEN THEN
            CLOSE v_policy_cur;
        END IF;

        BEGIN
            v_sql := 'DELETE FROM ' || v_tgt_schema || '.GTT_Policy_To_Copy_Preserve_Records';
            EXECUTE IMMEDIATE v_sql;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- best-effort cleanup
        END;

        RAISE;
        
END;
/