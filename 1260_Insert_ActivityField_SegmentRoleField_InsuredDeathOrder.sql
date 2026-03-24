DECLARE 
    VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);

    VRESULT VARCHAR2(200);

BEGIN
	-- Insert AsRoleField InsuredDeathOrder for Insured
	VSQL1:= '
		INSERT INTO AsRoleField (RoleGUID, FieldName,FieldTypeCode,TextValue,OptionTextFlag,OptionText)
		SELECT AsRole.RoleGUID, ''InsuredDeathOrder'' AS FieldName, ''02'' AS FieldTypeCode, ''00'' AS TextValue, 1 AS OptionTextFlag, ''AsCodeComboBlankLD'' AS OptionText
		FROM AsRole
		WHERE AsRole.RoleCode = ''37''
			AND AsRole.RoleGUID NOT IN (
				SELECT RoleGUID 
				FROM AsRoleField 
				WHERE FieldName = ''InsuredDeathOrder''
				)
			';

	-- Insert ActivityField InsuredDeathOrder in ProcessInsuredClaim and StartInsuredClaimProcess
	VSQL2:='
		INSERT INTO AsActivityField (ActivityGUID, FieldName,FieldTypeCode,TextValue,OptionTextFlag,OptionText)
		SELECT AsActivity.ActivityGUID, ''InsuredDeathOrder'' AS FieldName, ''02'' AS FieldTypeCode, ''F'' AS TextValue, 1 AS OptionTextFlag, ''AsCodeDeathOrder.LastDeathSD'' AS OptionText
		FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
			AND TransactionName IN (''ProcessInsuredClaim'',''StartInsuredClaimProcess'')
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT AsActivity.ActivityGUID 
			FROM AsActivity 
			JOIN AsActivityField ON AsActivityField.ActivityGUID=AsActivity.ActivityGUID 
				AND AsActivityField.FieldName = ''InsuredDeathOrder''
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
				AND TransactionName IN (''ProcessInsuredClaim'',''StartInsuredClaimProcess'')
			)
			';
			
	
VRESULT := NULL;
    EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );
END;
/