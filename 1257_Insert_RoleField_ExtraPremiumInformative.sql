DECLARE 
    VSQL1 VARCHAR2(32767);
    VSQL2 VARCHAR2(32767);
    VSQL3 VARCHAR2(32767);
    VSQL4 VARCHAR2(32767);
    VSQL5 VARCHAR2(32767);
    VSQL6 VARCHAR2(32767);
    VSQL7 VARCHAR2(32767);
    VSQL8 VARCHAR2(32767);
    VRESULT VARCHAR2(200);

BEGIN
	-- Insert RoleField CoverageExtraPremiumDurationInformativePRD on Insured 
	VSQL1:=
		'
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, IntValue)
		SELECT RoleGUID, ''CoverageExtraPremiumDurationInformativePRD'', ''03'', 0
		FROM AsRole 		
		WHERE RoleCode = ''37''
			AND StatusCode = ''01''
		AND RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''CoverageExtraPremiumDurationInformativePRD''
			)
		';
        
    -- Insert RoleField CoverageExtraPremiumDurationInformativePRP on Insured 
	VSQL2:=
		'
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, IntValue)
		SELECT RoleGUID, ''CoverageExtraPremiumDurationInformativePRP'', ''03'', 0
		FROM AsRole 		
		WHERE RoleCode = ''37''
			AND StatusCode = ''01''
		AND RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''CoverageExtraPremiumDurationInformativePRP''
			)
		';
        
    -- Insert RoleField CoverageExtraPremiumRatingInformativePRD on Insured 
	VSQL3:=
		'
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue)
		SELECT RoleGUID, ''CoverageExtraPremiumRatingInformativePRD'', ''04'', 0
		FROM AsRole 		
		WHERE RoleCode = ''37''
			AND StatusCode = ''01''
		AND RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''CoverageExtraPremiumRatingInformativePRD''
			)
		';
        
    -- Insert RoleField CoverageExtraPremiumRatingInformativePRP on Insured 
	VSQL4:=
		'
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue)
		SELECT RoleGUID, ''CoverageExtraPremiumRatingInformativePRP'', ''04'', 0
		FROM AsRole 		
		WHERE RoleCode = ''37''
			AND StatusCode = ''01''
		AND RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''CoverageExtraPremiumRatingInformativePRP''
			)
		';
        
    -- Insert RoleField CoverageExtraPremiumTotalAmountInformativePRD on Insured 
	VSQL5:=
		'
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue)
		SELECT RoleGUID, ''CoverageExtraPremiumTotalAmountInformativePRD'', ''04'', 0
		FROM AsRole 		
		WHERE RoleCode = ''37''
			AND StatusCode = ''01''
		AND RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''CoverageExtraPremiumTotalAmountInformativePRD''
			)
		';
        
    -- Insert RoleField CoverageExtraPremiumTotalAmountInformativePRP on Insured 
	VSQL6:=
		'
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue)
		SELECT RoleGUID, ''CoverageExtraPremiumTotalAmountInformativePRP'', ''04'', 0
		FROM AsRole 		
		WHERE RoleCode = ''37''
			AND StatusCode = ''01''
		AND RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''CoverageExtraPremiumTotalAmountInformativePRP''
			)
		';
        
    -- Insert RoleField CoverageExtraPremiumTypeCodeInformativePRD on Insured 
	VSQL7:=
		'
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
		SELECT RoleGUID, ''CoverageExtraPremiumTypeCodeInformativePRD'', ''02'', ''PRD'', 1, ''AsCodeExtraPremiumType.PRDLD''
		FROM AsRole 		
		WHERE RoleCode = ''37''
			AND StatusCode = ''01''
		AND RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''CoverageExtraPremiumTypeCodeInformativePRD''
			)
		';
        
    -- Insert RoleField CoverageExtraPremiumTypeCodeInformativePRP on Insured 
	VSQL8:=
		'
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
		SELECT RoleGUID, ''CoverageExtraPremiumTypeCodeInformativePRP'', ''02'', ''PRP'', 1, ''AsCodeExtraPremiumType.PRPLD''
		FROM AsRole 		
		WHERE RoleCode = ''37''
			AND StatusCode = ''01''
		AND RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''CoverageExtraPremiumTypeCodeInformativePRP''
			)
		';

VRESULT := NULL;

    EXECUTESQL ( VSQL1, VRESULT );
    EXECUTESQL ( VSQL2, VRESULT );
    EXECUTESQL ( VSQL3, VRESULT );
    EXECUTESQL ( VSQL4, VRESULT );
    EXECUTESQL ( VSQL5, VRESULT );
    EXECUTESQL ( VSQL6, VRESULT );
    EXECUTESQL ( VSQL7, VRESULT );
    EXECUTESQL ( VSQL8, VRESULT );

END;
/