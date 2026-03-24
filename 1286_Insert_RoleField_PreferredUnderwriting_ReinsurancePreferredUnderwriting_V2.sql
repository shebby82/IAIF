DECLARE
	VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);
	VSQL3 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN
VSQL1:= '
	INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
	SELECT RoleGUID, ''PreferredUnderwriting'', ''02'', ''S'', ''1'' , ''AsCodeUnderwritingClass.StandardLD''
	FROM AsRole
	WHERE RoleCode = ''37''
	AND RoleGUID NOT IN 
	(
		SELECT DISTINCT(AsRole.RoleGUID)
		FROM AsRole
		JOIN AsRoleField ON AsRoleField.RoleGUID = AsRole.RoleGUID
			AND AsRoleField.FieldName = ''PreferredUnderwriting''
	)
	';

VSQL2:= '
	INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
	SELECT RoleGUID, ''ReinsurancePreferredUnderwriting'', ''02'', ''S'', ''1'' , ''AsCodeUnderwritingClass.StandardLD''
	FROM AsRole
	WHERE RoleCode = ''97''
	AND RoleGUID NOT IN 
	(
		SELECT DISTINCT(AsRole.RoleGUID)
		FROM AsRole
		JOIN AsRoleField ON AsRoleField.RoleGUID = AsRole.RoleGUID
			AND AsRoleField.FieldName = ''ReinsurancePreferredUnderwriting''
	)
	';

VSQL3:= '
	INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
	SELECT ActivityGUID, ''InsuredPreferredUnderwriting'', ''02'', ''S'', ''1'' , ''AsCodeUnderwritingClass.StandardLD''
	FROM (
		SELECT AsActivity.ActivityGUID
		FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''ApplyCoverageRolesChangesFromApplication'', ''AddRolesOnCoverage'')
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT AsActivity.ActivityGUID
			FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
				AND AsTransaction.TransactionName IN (''ApplyCoverageRolesChangesFromApplication'', ''AddRolesOnCoverage'')
			JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
				AND AsActivityField.FieldName = ''InsuredPreferredUnderwriting''
			)
		)
	';


VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );
	EXECUTESQL ( VSQL3, VRESULT );

END;
/