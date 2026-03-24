DECLARE
    v_existing_rows		NUMBER := 0;
    v_affected_rows		NUMBER := 0;
    v_operation_type	VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'GetCoverageRoles';
    v_application_name VARCHAR2(50) := 'Modernia';
    v_version_number NUMBER := 10;
    v_currentuser VARCHAR(50) := 'ServiceLayer_IA';

    v_query_value CLOB := 
		'SELECT 
			AsRole.RoleGUID,
			AsRole.RoleCode,
			AsRoleField.FieldName,
			AsRoleField.DateValue,
			AsRoleField.TextValue,
			AsRoleField.IntValue,
			AsRoleField.FloatValue,
			AsRole.RolePercent,
			AsRole.ClientGUID
		FROM AsRole
		LEFT JOIN AsRoleField 
			ON AsRole.RoleGUID = AsRoleField.RoleGUID
		WHERE 
			AsRole.SegmentGUID = ''[SegmentGUID]''
			AND AsRole.StatusCode IN (''01'',''02'')
		ORDER BY 
			AsRole.RoleCode,
			AsRole.ClientGUID';

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