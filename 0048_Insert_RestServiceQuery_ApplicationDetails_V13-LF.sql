DECLARE
    v_existing_rows		NUMBER := 0;
    v_affected_rows		NUMBER := 0;
    v_operation_type	VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'ApplicationDetails';
    v_application_name VARCHAR2(50) := 'ApplicationOIPA';
    v_version_number NUMBER := 13;
    v_currentuser VARCHAR(50) := 'ServiceLayer_IA';

    v_query_value CLOB := 
		'WITH app AS (
    SELECT POLICYGUID, POLICYNUMBER
    FROM   AsPOLICY
    WHERE  POLICYNUMBER = ''[ApplicationNumber]''
    AND    SYSTEMCODE   = ''02''
),
iden AS (
    SELECT /*+ NO_MERGE */ DISTINCT
           a.POLICYGUID,
           pf.TEXTVALUE AS ApplicationIdentifier
    FROM   ASACTIVITY a
           JOIN AsPolicyField pf
             ON pf.PolicyGUID = a.PolicyGUID
            AND pf.FieldName  = ''ApplicationIdentifier''
           JOIN app
             ON app.POLICYGUID = a.POLICYGUID
),
deposit AS (
    SELECT /*+ NO_MERGE */
           a.POLICYGUID,
           pf.TEXTVALUE AS ApplicationIdentifier,
           f.FLOATVALUE AS DepositWithApplication,
           MAX(a.EffectiveDate) AS LastEffectiveDate
    FROM   ASACTIVITY a
           JOIN AsPolicyField pf
             ON pf.PolicyGUID = a.PolicyGUID
            AND pf.FieldName  = ''ApplicationIdentifier''
           JOIN ASTRANSACTION t
             ON t.TransactionGUID = a.TransactionGUID
            AND t.TransactionGUID IN (''BED59927-3892-4891-AE80-54BC72097442'',''C361FD1B-18CA-4352-B3B0-31621BD9A2FC'')
           JOIN ASACTIVITYFIELD f
             ON f.ACTIVITYGUID = a.ACTIVITYGUID
            AND f.FIELDNAME    = ''Amount''
           JOIN AsActivitySpawn aas
             ON aas.ActivityGUID = a.ActivityGUID
           JOIN AsActivity asb
             ON asb.ActivityGUID = aas.SpawnedByGUID
           JOIN AsTransaction sbt
             ON sbt.TransactionGUID = asb.TransactionGUID
            AND sbt.TransactionGUID IN (''9ECDA720-C285-4740-B30A-C28D8FBD3931'',''A3CA28FC-E492-43C8-9940-F1DF7F07CE7A'',''915D6D87-933D-40DB-90E0-88675ADD081F'')
           JOIN app
             ON app.POLICYGUID = a.POLICYGUID
    WHERE  a.TYPECODE   IN (''01'',''04'')
    AND    a.STATUSCODE  = ''01''
    GROUP  BY a.POLICYGUID, pf.TEXTVALUE, f.FLOATVALUE
),
cancelDate AS (
    SELECT /*+ NO_MERGE */
           a.POLICYGUID,
           pf.TEXTVALUE AS ApplicationIdentifier,
           f.DATEVALUE  AS CancelApplicatonRequestDate
    FROM   ASACTIVITY a
           JOIN AsPolicyField pf
             ON pf.PolicyGUID = a.PolicyGUID
            AND pf.FieldName  = ''ApplicationIdentifier''
           JOIN ASTRANSACTION t
             ON t.TransactionGUID = a.TransactionGUID
            AND t.TransactionGUID IN (''9C9BDB90-7C03-4732-9C41-5D2C0396E440'')
           JOIN ASACTIVITYFIELD f
             ON f.ACTIVITYGUID = a.ACTIVITYGUID
            AND f.FIELDNAME    = ''RequestDate''
           JOIN app
             ON app.POLICYGUID = a.POLICYGUID
    WHERE  a.TYPECODE   IN (''01'',''04'')
    AND    a.STATUSCODE  = ''01''
)
SELECT
    app.POLICYNUMBER AS ApplicationNumber,
    iden.ApplicationIdentifier,
    deposit.DepositWithApplication,
    cancelDate.CancelApplicatonRequestDate
FROM   app
       JOIN iden
         ON iden.POLICYGUID = app.POLICYGUID
       LEFT JOIN deposit
         ON deposit.POLICYGUID = iden.POLICYGUID
        AND deposit.ApplicationIdentifier = iden.ApplicationIdentifier
       LEFT JOIN cancelDate
         ON cancelDate.POLICYGUID = iden.POLICYGUID
        AND cancelDate.ApplicationIdentifier = iden.ApplicationIdentifier';

BEGIN
    -- Check if a row with the same QueryName, ApplicationName and VersionNumber already exists
    SELECT COUNT(*)
    INTO   v_existing_rows
    FROM   ASRESTSERVICEQUERY
    WHERE  QUERYNAME       = v_query_name
      AND  APPLICATIONNAME = v_application_name
      AND  VERSIONNUMBER   = v_version_number;

    -- Perform INSERT or UPDATE based on existence
    IF v_existing_rows > 0 THEN
        -- Update existing row
        UPDATE ASRESTSERVICEQUERY
        SET    QUERYVALUE = v_query_value
        WHERE  QUERYNAME       = v_query_name
          AND  APPLICATIONNAME = v_application_name
          AND  VERSIONNUMBER   = v_version_number;

        v_operation_type := 'updated';
    ELSE
        -- Insert new row
        INSERT INTO AsRestServiceQuery (RestServiceQueryGUID, QueryName, VersionNumber, QueryValue, ApplicationName, SystemIndicator, CreatedGMT, CreatedUser)
        VALUES (NEWID(), v_query_name, v_version_number, v_query_value, v_application_name, 'N', current_date, v_currentuser );

        v_operation_type := 'inserted';
    END IF;
    
    v_affected_rows := SQL%ROWCOUNT;

    -- Output the operation type and affected rows
    DBMS_OUTPUT.PUT_LINE(v_affected_rows || ' row(s) ' || v_operation_type || '.' );
END;
/