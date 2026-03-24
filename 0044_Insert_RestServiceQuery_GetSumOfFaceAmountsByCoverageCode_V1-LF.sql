DECLARE
    v_existing_rows   NUMBER := 0;
    v_affected_rows   NUMBER := 0;
    v_operation_type  VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'GetSumOfFaceAmountsByCoverageCode';
    v_application_name VARCHAR2(50) := 'Modernia';
    v_version_number NUMBER := 1;

    v_query_value CLOB := '
	    SELECT CoverageCode.TextValue As CoverageCode, SUM(FaceAmount.FloatValue) AS FaceAmount
        FROM AsSegmentField FaceAmount
        JOIN AsSegmentField CoverageCode ON FaceAmount.SegmentGUID = CoverageCode.SegmentGUID 
            AND CoverageCode.FieldName = ''CoverageCode''
        JOIN AsSegment ON FaceAmount.SegmentGUID = AsSegment.SegmentGUID
        JOIN AsPolicy ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID 
            AND SystemCode = ''01'' AND AsPolicy.StatusCode = ''01''
        WHERE FaceAmount.FieldName = ''FaceAmount''
            AND ((''[PolicyNumbers]'' IS NULL OR TRIM(''[PolicyNumbers]'') = '''')
            OR INSTR(''[PolicyNumbers]'', AsPolicy.PolicyNumber) > 0)
        GROUP BY CoverageCode.TextValue,AsPolicy.PolicyNumber
	';

BEGIN
    SELECT COUNT(*)
    INTO   v_existing_rows
    FROM   ASRESTSERVICEQUERY
    WHERE  QUERYNAME       = v_query_name
      AND  APPLICATIONNAME = v_application_name
      AND  VERSIONNUMBER   = v_version_number;

    IF v_existing_rows > 0 THEN
        UPDATE ASRESTSERVICEQUERY
        SET    QUERYVALUE = v_query_value
        WHERE  QUERYNAME       = v_query_name
          AND  APPLICATIONNAME = v_application_name
          AND  VERSIONNUMBER   = v_version_number;

        v_operation_type := 'updated';
    ELSE
        INSERT INTO AsRestServiceQuery (RestServiceQueryGUID, QueryName, VersionNumber, QueryValue, ApplicationName)
        VALUES (NEWID(), v_query_name, v_version_number, v_query_value, v_application_name);

        v_operation_type := 'inserted';
    END IF;

    v_affected_rows := SQL%ROWCOUNT;

    DBMS_OUTPUT.PUT_LINE(v_affected_rows || ' row(s) ' || v_operation_type || '.' );
END;
/