DECLARE
    v_existing_rows		NUMBER := 0;
    v_affected_rows		NUMBER := 0;
    v_operation_type	VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'GetPolicyClients';
    v_application_name VARCHAR2(50) := 'Modernia';
    v_version_number NUMBER := 7;
    v_currentuser VARCHAR(50) := 'ServiceLayer_IA';

    v_query_value CLOB := 
      'SELECT DISTINCT
          Role.ClientGUID AS ClientId,
          ClientPartyId.TextValue AS PartyId,
          ClientPolicyPartyId.TextValue AS PolicyPartyId,
          Client.TextField1,
          Client.TextField2,
          Client.TypeCode AS TYPE
       FROM AsRole Role
          LEFT JOIN AsSegment Seg
             ON Seg.SegmentGuid = Role.SegmentGuid
          LEFT JOIN AsPolicy Pol
             ON Pol.PolicyGuid = Seg.PolicyGuid
             OR Pol.PolicyGuid = Role.PolicyGuid
          LEFT JOIN AsClient Client
             ON Client.ClientGuid = Role.ClientGuid
          LEFT JOIN AsClientField ClientPartyId
             ON ClientPartyId.ClientGuid = Client.ClientGuid
             AND LOWER(ClientPartyId.FieldName) = ''partyid''
          LEFT JOIN AsClientField ClientPolicyPartyId
             ON ClientPolicyPartyId.ClientGuid = Client.ClientGuid
             AND LOWER(ClientPolicyPartyId.FieldName) = ''policypartyid''
       WHERE Pol.PolicyNumber = ''[policyNumber]''
         AND Role.StatusCode IN (''01'', ''02'')';

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