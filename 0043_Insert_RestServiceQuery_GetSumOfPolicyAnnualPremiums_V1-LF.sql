DECLARE
    v_existing_rows   NUMBER := 0;
    v_affected_rows   NUMBER := 0;
    v_operation_type  VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'GetSumOfPolicyAnnualPremiums';
    v_application_name VARCHAR2(50) := 'Modernia';
    v_version_number NUMBER := 1;

    v_query_value CLOB := '
	SELECT SUBSTR(ProductVersionCode.TextValue, 1, INSTR(ProductVersionCode.TextValue, ''-'') - 1) AS ProductName,
        SUM(AnnualPremium.FloatValue) AS TotalAnnualPremium
    FROM AsPolicyField AnnualPremium
    JOIN AsPolicyField ProductVersionCode 
        ON ProductVersionCode.PolicyGUID = AnnualPremium.PolicyGUID 
        AND ProductVersionCode.FieldName = ''ProductVersionCode''
    JOIN AsPolicy 
        ON AsPolicy.PolicyGUID = ProductVersionCode.PolicyGUID 
        AND AsPolicy.StatusCode = ''01'' 
        AND AsPolicy.SystemCode = ''01''
    WHERE AnnualPremium.FieldName = ''PolicyAnnualPremium''
        AND (
                (''[PolicyNumbers]'' IS NULL OR TRIM(''[PolicyNumbers]'') = '''')
                OR INSTR(''[PolicyNumbers]'', AsPolicy.PolicyNumber) > 0
        )
        GROUP BY SUBSTR(ProductVersionCode.TextValue, 1, INSTR(ProductVersionCode.TextValue, ''-'') - 1)
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