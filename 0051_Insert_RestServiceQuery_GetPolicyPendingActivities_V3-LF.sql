DECLARE
    v_existing_rows		NUMBER := 0;
    v_affected_rows		NUMBER := 0;
    v_operation_type	VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'GetPolicyPendingActivities';
    v_application_name VARCHAR2(50) := 'Modernia';
    v_version_number NUMBER := 3;
    v_currentuser VARCHAR(50) := 'ServiceLayer_IA';

    v_query_value CLOB := 
q'!SELECT CASE 
        WHEN PendingActivityCount > 0 THEN 'true'
        ELSE 'false'
    END AS IsPolicyProcessing
FROM (
  SELECT COUNT(AsActivity.ActivityGUID) AS PendingActivityCount
  FROM AsPolicy
  JOIN AsActivity ON AsActivity.PolicyGUID = AsPolicy.PolicyGUID
      AND AsActivity.StatusCode IN ('02', '09')
      AND AsActivity.TypeCode IN ('01','04')
      AND AsActivity.EffectiveDate < (SELECT TRUNC(SystemDate) FROM AsSystemDate WHERE CurrentIndicator = 'Y')
  WHERE AsPolicy.PolicyNumber = '[PolicyNumber]'
      AND AsPolicy.SystemCode = '01'
)!';

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