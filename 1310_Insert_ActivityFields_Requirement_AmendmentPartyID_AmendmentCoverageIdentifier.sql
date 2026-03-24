DECLARE
	VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);
	VSQL3 VARCHAR2(32767);
	VSQL4 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN


VSQL1:= '
	INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
	SELECT ActivityGUID, ''AmendmentCoverageIdentifier'', ''02'', ''00'', 1, ''AsCodeComboPleaseSelectSD''
	FROM AsActivity
	JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
		AND AsTransaction.TransactionName IN (''CreateAmendment'',''SpawnAmendmentCreation'')
	WHERE ActivityGUID NOT IN 
	(
		SELECT DISTINCT(AsActivityField.ActivityGUID)
		FROM AsActivityField
		WHERE AsActivityField.FieldName = ''AmendmentCoverageIdentifier''
	)
	';
VSQL2:= '
	INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
	SELECT ActivityGUID, ''AmendmentPartyID'', ''02'', ''00'', 1, ''AsCodeComboNASD''
	FROM AsActivity
	JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
		AND AsTransaction.TransactionName IN (''CreateAmendment'',''SpawnAmendmentCreation'')
	WHERE ActivityGUID NOT IN 
	(
		SELECT DISTINCT(AsActivityField.ActivityGUID)
		FROM AsActivityField
		WHERE AsActivityField.FieldName = ''AmendmentPartyID''
	)
	';
VSQL3:= '
	INSERT INTO AsRequirementField (RequirementGUID, FieldName, FieldTypeCode)
	SELECT RequirementGUID, ''AmendmentCoverageIdentifier'', ''02''
	FROM AsRequirement
    JOIN AsRequirementDefinition ON AsRequirementDefinition.RequirementDefinitionGUID = AsRequirement.RequirementDefinitionGUID
         AND AsRequirementDefinition.RequirementName = ''Requirement.Amendment''
	WHERE RequirementGUID NOT IN 
	(
		SELECT DISTINCT(AsRequirement.RequirementGUID)
		FROM AsRequirement 
        JOIN AsRequirementDefinition ON AsRequirementDefinition.RequirementDefinitionGUID = AsRequirement.RequirementDefinitionGUID
			AND AsRequirementDefinition.RequirementName = ''Requirement.Amendment''
        JOIN AsRequirementField AmendmentCoverageIdentifier ON AmendmentCoverageIdentifier.RequirementGUID = AsRequirement.RequirementGUID
			AND AmendmentCoverageIdentifier.FieldName = ''AmendmentCoverageIdentifier''
	)
	';
VSQL4:= '
	INSERT INTO AsRequirementField (RequirementGUID, FieldName, FieldTypeCode)
	SELECT RequirementGUID, ''AmendmentPartyID'', ''02''
	FROM AsRequirement
    JOIN AsRequirementDefinition ON AsRequirementDefinition.RequirementDefinitionGUID = AsRequirement.RequirementDefinitionGUID
         AND AsRequirementDefinition.RequirementName = ''Requirement.Amendment''
	WHERE RequirementGUID NOT IN 
	(
		SELECT DISTINCT(AsRequirement.RequirementGUID)
		FROM AsRequirement 
        JOIN AsRequirementDefinition ON AsRequirementDefinition.RequirementDefinitionGUID = AsRequirement.RequirementDefinitionGUID
			AND AsRequirementDefinition.RequirementName = ''Requirement.Amendment''
        JOIN AsRequirementField AmendmentPartyID ON AmendmentPartyID.RequirementGUID = AsRequirement.RequirementGUID
			AND AmendmentPartyID.FieldName = ''AmendmentPartyID''
	)
	';

VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );
	EXECUTESQL ( VSQL3, VRESULT );
	EXECUTESQL ( VSQL4, VRESULT );
END;
/