
DECLARE
    v_existing_rows   NUMBER := 0;
    v_affected_rows   NUMBER := 0;
    v_operation_type  VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'GetAmendmentsInformation';
    v_application_name VARCHAR2(50) := 'Modernia';
    v_version_number NUMBER := 1;

    v_query_value CLOB := '
		Select 
      RequirementAmendmentNumber.TextValue As AmendmentNumber,
      AmendmentCoverageIdentifier.TextValue As CoverageIdentifier,
      AmendmentPartyID.TextValue As PartyID,
      CASE 
        WHEN AmendmentSignatureRequired.TextValue = ''CHECKED'' THEN 
          ''true'' 
        ELSE ''false'' 
      END As AmendmentSignatureRequired,
      CASE 
        WHEN AmendmentSignedIndicator.TextValue = ''CHECKED'' THEN 
          ''true'' 
        ELSE ''false'' 
      END As AmendmentSignedIndicator,
      TO_CHAR(AmendmentSignedDate.DateValue, ''YYYY-MM-DD'') AS AmendmentSignedDate, 
      RequirementAmendmentParameterValue1.TextValue As AmendmentParameterValue1,
      RequirementAmendmentParameterValue2.TextValue As AmendmentParameterValue2,
      RequirementAmendmentParameterValue3.TextValue As AmendmentParameterValue3,
      RequirementAmendmentParameterValue4.TextValue As AmendmentParameterValue4,
      RequirementAmendmentParameterValue5.TextValue As AmendmentParameterValue5,
      RequirementAmendmentParameterValue6.TextValue As AmendmentParameterValue6,
      RequirementAmendmentParameterValue7.TextValue As AmendmentParameterValue7,
      RequirementAmendmentParameterValue8.TextValue As AmendmentParameterValue8,
      RequirementAmendmentParameterValue9.TextValue As AmendmentParameterValue9,
      RequirementAmendmentParameterValue10.TextValue As AmendmentParameterValue10,
      RequirementAmendmentParameterValue11.TextValue As AmendmentParameterValue11,            
      AmendmentTextLanguage.TextValue As AmendmentTextLanguage
		FROM AsRequirement PolicyRequirement
		JOIN AsRequirementDefinition ON AsRequirementDefinition.RequirementDefinitionGUID = PolicyRequirement.RequirementDefinitionGUID
		JOIN AsRequirementPolicy ON AsRequirementPolicy.RequirementGUID = PolicyRequirement.RequirementGUID
		JOIN AsRequirementField RequirementAmendmentNumber ON RequirementAmendmentNumber.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentNumber.FieldName = ''AmendmentNumber''
		JOIN AsRequirementField RequirementAmendmentParameterValue1 ON RequirementAmendmentParameterValue1.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue1.FieldName = ''AmendmentParameterValue1''
		JOIN AsRequirementField RequirementAmendmentParameterValue2 ON RequirementAmendmentParameterValue2.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue2.FieldName = ''AmendmentParameterValue2''
		JOIN AsRequirementField RequirementAmendmentParameterValue3 ON RequirementAmendmentParameterValue3.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue3.FieldName = ''AmendmentParameterValue3''
        JOIN AsRequirementField RequirementAmendmentParameterValue4 ON RequirementAmendmentParameterValue4.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue4.FieldName = ''AmendmentParameterValue4''
        JOIN AsRequirementField RequirementAmendmentParameterValue5 ON RequirementAmendmentParameterValue5.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue5.FieldName = ''AmendmentParameterValue5''
        JOIN AsRequirementField RequirementAmendmentParameterValue6 ON RequirementAmendmentParameterValue6.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue6.FieldName = ''AmendmentParameterValue6''
        JOIN AsRequirementField RequirementAmendmentParameterValue7 ON RequirementAmendmentParameterValue7.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue7.FieldName = ''AmendmentParameterValue7''
        JOIN AsRequirementField RequirementAmendmentParameterValue8 ON RequirementAmendmentParameterValue8.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue8.FieldName = ''AmendmentParameterValue8''
        JOIN AsRequirementField RequirementAmendmentParameterValue9 ON RequirementAmendmentParameterValue9.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue9.FieldName = ''AmendmentParameterValue9''
        JOIN AsRequirementField RequirementAmendmentParameterValue10 ON RequirementAmendmentParameterValue10.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue10.FieldName = ''AmendmentParameterValue10''
        JOIN AsRequirementField RequirementAmendmentParameterValue11 ON RequirementAmendmentParameterValue11.RequirementGUID = PolicyRequirement.RequirementGUID
			AND RequirementAmendmentParameterValue11.FieldName = ''AmendmentParameterValue10''
		JOIN AsRequirementField AmendmentSignatureRequired ON AmendmentSignatureRequired.RequirementGUID = PolicyRequirement.RequirementGUID
			AND AmendmentSignatureRequired.FieldName = ''AmendmentSignatureRequired''
		JOIN AsRequirementField AmendmentSignedIndicator ON AmendmentSignedIndicator.RequirementGUID = PolicyRequirement.RequirementGUID
			AND AmendmentSignedIndicator.FieldName = ''AmendmentSignedIndicator''
		JOIN AsRequirementField AmendmentSignedDate ON AmendmentSignedDate.RequirementGUID = PolicyRequirement.RequirementGUID
			AND AmendmentSignedDate.FieldName = ''AmendmentSignedDate''
		JOIN AsRequirementField AmendmentTextLanguage ON AmendmentTextLanguage.RequirementGUID = PolicyRequirement.RequirementGUID
			AND AmendmentTextLanguage.FieldName = ''AmendmentTextLanguage''
        JOIN AsRequirementField AmendmentCoverageIdentifier ON AmendmentCoverageIdentifier.RequirementGUID = PolicyRequirement.RequirementGUID
			AND AmendmentCoverageIdentifier.FieldName = ''AmendmentCoverageIdentifier''
        JOIN AsRequirementField AmendmentPartyID ON AmendmentPartyID.RequirementGUID = PolicyRequirement.RequirementGUID
			AND AmendmentPartyID.FieldName = ''AmendmentPartyID''      
		JOIN AsPolicy CreateAmendmentPolicy ON AsRequirementPolicy.PolicyGUID = CreateAmendmentPolicy.PolicyGUID
			AND CreateAmendmentPolicy.PolicyNumber = ''[PolicyNumber]''				
		WHERE AsRequirementDefinition.RequirementName = ''Requirement.Amendment''
			AND PolicyRequirement.StatusCode NOT IN (''DELETED'')
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