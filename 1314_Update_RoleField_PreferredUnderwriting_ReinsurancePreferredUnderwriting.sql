DECLARE 
    VSQL1 VARCHAR2(32767);
    VRESULT VARCHAR2(200);
    
BEGIN
    VSQL1:='
	UPDATE AsRoleField 
	SET OptionTextFlag = ''1'',
		OptionText =
			CASE
				WHEN TextValue = ''S'' THEN ''AsCodeUnderwritingClass.StandardLD''
				WHEN TextValue = ''P'' THEN ''AsCodeUnderwritingClass.PrivilegedLD''
				WHEN TextValue = ''E'' THEN ''AsCodeUnderwritingClass.EliteLD''
			END
	WHERE FieldName IN (''PreferredUnderwriting'',''ReinsurancePreferredUnderwriting'') 
		AND TextValue IS NOT NULL
		AND OptionText IS NULL
		AND OptionTextFlag IS NULL
        ';
    
VRESULT := NULL;

EXECUTESQL ( VSQL1, VRESULT );
    
END;
/