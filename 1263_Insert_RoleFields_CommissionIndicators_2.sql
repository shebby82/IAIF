DECLARE 
	VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);
	VSQL3 VARCHAR2(32767);
	VSQL4 VARCHAR2(32767);
    VSQL5 VARCHAR2(32767);
	VSQL6 VARCHAR2(32767);
    VRESULT VARCHAR2(200);

BEGIN
	
	VSQL1:=
		'
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
		SELECT RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText
		FROM 
		(  
			SELECT *
			FROM 
			(
				SELECT AsRole.RoleGUID AS RoleGUID, ''CoverageExtraPremiumCommissionCodePRP'' AS FieldName, ''02'' AS FieldTypeCode, AsMapValue.TextValue AS TextValue, 1 AS OptionTextFlag,
					CASE
						WHEN AsMapValue.TextValue = ''CMS'' THEN ''AsCodeExtraPremiumCommissionCode.CMSSD''
						WHEN AsMapValue.TextValue = ''C_N'' THEN ''AsCodeExtraPremiumCommissionCode.C_NSD''
						WHEN AsMapValue.TextValue = ''NCM'' THEN ''AsCodeExtraPremiumCommissionCode.NCMSD''
					END AS OptionText,
					CASE
						WHEN AsPolicyField.TextValue = ''02'' THEN ''true''
						ELSE ''false''
					END AS ApplicationSubType,
					MapConversionCoverageIndicator.TextValue AS MapConversionValue
				FROM AsRole
				JOIN AsSegment ON AsSegment.SegmentGUID = AsRole.SegmentGUID
				JOIN AsPolicy ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID
				JOIN AsSegmentField InsuranceBasis ON AsRole.SegmentGUID = InsuranceBasis.SegmentGUID
					AND InsuranceBasis.FieldName = ''InsuranceBasis''
				JOIN AsSegmentField CoverageCode ON AsRole.SegmentGUID = CoverageCode.SegmentGUID
					AND CoverageCode.FieldName = ''CoverageCode''
				JOIN AsRoleField ExtraPremiumTypeCode ON AsRole.RoleGUID = ExtraPremiumTypeCode.RoleGUID
					AND ExtraPremiumTypeCode.FieldName = ''CoverageExtraPremiumTypeCodePRP''
				JOIN AsRoleField CoverageExtraPremiumRatingPRP ON AsRole.RoleGUID = CoverageExtraPremiumRatingPRP.RoleGUID
					AND CoverageExtraPremiumRatingPRP.FieldName = ''CoverageExtraPremiumRatingPRP''
					AND CoverageExtraPremiumRatingPRP.FloatValue != 0
				JOIN AsPolicyField ON AsPolicyField.PolicyGUID = AsPolicy.PolicyGUID
					AND AsPolicyField.FieldName = ''ApplicationSubType''
				JOIN AsMapGroup ON AsMapGroup.MapGroupDescription = ''RISP_CoverageExtraPremiumCommission''
				JOIN AsMapValue ON AsMapValue.MapGroupGUID = AsMapGroup.MapGroupGUID
				JOIN AsMapCriteria MapCoverageCode ON MapCoverageCode.MapValueGUID = AsMapValue.MapValueGUID
					AND MapCoverageCode.MapCriteriaName = ''CoverageCode''
					AND MapCoverageCode.TextValue = CoverageCode.TextValue
				JOIN AsMapCriteria MapInsuranceBasis ON MapInsuranceBasis.MapValueGUID = AsMapValue.MapValueGUID
					AND MapInsuranceBasis.MapCriteriaName = ''InsuranceBasis''
					AND MapInsuranceBasis.TextValue = InsuranceBasis.TextValue
				JOIN AsMapCriteria MapConversionCoverageIndicator ON MapConversionCoverageIndicator.MapValueGUID = AsMapValue.MapValueGUID
					AND MapConversionCoverageIndicator.MapCriteriaName = ''ConversionCoverageIndicator''
				JOIN AsMapCriteria MapExtraPremiumTypeCode ON MapExtraPremiumTypeCode.MapValueGUID = AsMapValue.MapValueGUID
					AND MapExtraPremiumTypeCode.MapCriteriaName = ''ExtraPremiumTypeCode''
					AND MapExtraPremiumTypeCode.TextValue = ExtraPremiumTypeCode.TextValue
				WHERE AsRole.RoleCode = ''37''
					AND AsRole.RoleGUID NOT IN 
					(
						SELECT RoleGUID 
						FROM AsRoleField 
						WHERE FieldName = ''CoverageExtraPremiumCommissionCodePRP''
					)
			)
			WHERE MapConversionValue = ApplicationSubType
			UNION
			SELECT AsRole.RoleGUID AS RoleGUID, ''CoverageExtraPremiumCommissionCodePRP'' AS FieldName, ''02'' AS FieldTypeCode, ''00'' AS TextValue, 1 AS OptionTextFlag, ''AsCodeComboNASD'' AS OptionText, ''false'' AS ApplicationSubType, ''false'' AS MapConversionValue
			FROM AsRole
			JOIN AsRoleField CoverageExtraPremiumRatingPRP ON AsRole.RoleGUID = CoverageExtraPremiumRatingPRP.RoleGUID
					AND CoverageExtraPremiumRatingPRP.FieldName = ''CoverageExtraPremiumRatingPRP''
					AND CoverageExtraPremiumRatingPRP.FloatValue = 0
			WHERE AsRole.RoleCode = ''37''
					AND AsRole.RoleGUID NOT IN 
					(
						SELECT RoleGUID 
						FROM AsRoleField 
						WHERE FieldName = ''CoverageExtraPremiumCommissionCodePRP''
					)
		)
		';
		
	VSQL2:= 
		' 
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
		SELECT RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText
		FROM 
		(
			SELECT *
			FROM 
			(
				SELECT AsRole.RoleGUID AS RoleGUID, ''CoverageExtraPremiumCommissionCodePRD'' AS FieldName, ''02'' AS FieldTypeCode, AsMapValue.TextValue AS TextValue, 1 AS OptionTextFlag,
					CASE
						WHEN AsMapValue.TextValue = ''CMS'' THEN ''AsCodeExtraPremiumCommissionCode.CMSSD''
						WHEN AsMapValue.TextValue = ''C_N'' THEN ''AsCodeExtraPremiumCommissionCode.C_NSD''
						WHEN AsMapValue.TextValue = ''NCM'' THEN ''AsCodeExtraPremiumCommissionCode.NCMSD''
					END AS OptionText,
					CASE 
						WHEN AsPolicyField.TextValue = ''02'' THEN ''true''
						ELSE ''false''
					END AS ApplicationSubType,
					MapConversionCoverageIndicator.TextValue AS MapConversionValue
				FROM AsRole
				JOIN AsSegment ON AsSegment.SegmentGUID = AsRole.SegmentGUID
				JOIN AsPolicy ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID
				JOIN AsSegmentField InsuranceBasis ON AsRole.SegmentGUID = InsuranceBasis.SegmentGUID
					AND InsuranceBasis.FieldName = ''InsuranceBasis''
				JOIN AsSegmentField CoverageCode ON AsRole.SegmentGUID = CoverageCode.SegmentGUID
					AND CoverageCode.FieldName = ''CoverageCode''
				JOIN AsRoleField ExtraPremiumTypeCode ON AsRole.RoleGUID = ExtraPremiumTypeCode.RoleGUID
					AND ExtraPremiumTypeCode.FieldName = ''CoverageExtraPremiumTypeCodePRD''
				JOIN AsRoleField CoverageExtraPremiumAmountPRD ON AsRole.RoleGUID = CoverageExtraPremiumAmountPRD.RoleGUID
					AND CoverageExtraPremiumAmountPRD.FieldName = ''CoverageExtraPremiumAmountPRD''
					AND CoverageExtraPremiumAmountPRD.FloatValue != 0
				JOIN AsPolicyField ON AsPolicyField.PolicyGUID = AsPolicy.PolicyGUID
					AND AsPolicyField.FieldName = ''ApplicationSubType''
				JOIN AsMapGroup ON AsMapGroup.MapGroupDescription = ''RISP_CoverageExtraPremiumCommission''
				JOIN AsMapValue ON AsMapValue.MapGroupGUID = AsMapGroup.MapGroupGUID
				JOIN AsMapCriteria MapCoverageCode ON MapCoverageCode.MapValueGUID = AsMapValue.MapValueGUID
					AND MapCoverageCode.MapCriteriaName = ''CoverageCode''
					AND MapCoverageCode.TextValue = CoverageCode.TextValue
				JOIN AsMapCriteria MapInsuranceBasis ON MapInsuranceBasis.MapValueGUID = AsMapValue.MapValueGUID
					AND MapInsuranceBasis.MapCriteriaName = ''InsuranceBasis''
					AND MapInsuranceBasis.TextValue = InsuranceBasis.TextValue
				JOIN AsMapCriteria MapConversionCoverageIndicator ON MapConversionCoverageIndicator.MapValueGUID = AsMapValue.MapValueGUID
					AND MapConversionCoverageIndicator.MapCriteriaName = ''ConversionCoverageIndicator''
				JOIN AsMapCriteria MapExtraPremiumTypeCode ON MapExtraPremiumTypeCode.MapValueGUID = AsMapValue.MapValueGUID
					AND MapExtraPremiumTypeCode.MapCriteriaName = ''ExtraPremiumTypeCode''
					AND MapExtraPremiumTypeCode.TextValue = ExtraPremiumTypeCode.TextValue
				WHERE AsRole.RoleCode = ''37''
					AND AsRole.RoleGUID NOT IN 
					(
						SELECT RoleGUID 
						FROM AsRoleField 
						WHERE FieldName = ''CoverageExtraPremiumCommissionCodePRD''
					)
			)
			WHERE MapConversionValue = ApplicationSubType
			UNION
			SELECT AsRole.RoleGUID AS RoleGUID, ''CoverageExtraPremiumCommissionCodePRD'' AS FieldName, ''02'' AS FieldTypeCode, ''00'' AS TextValue, 1 AS OptionTextFlag, ''AsCodeComboNASD'' AS OptionText, ''false'' AS ApplicationSubType, ''false'' AS MapConversionValue
			FROM AsRole
			JOIN AsRoleField CoverageExtraPremiumAmountPRD ON AsRole.RoleGUID = CoverageExtraPremiumAmountPRD.RoleGUID
				AND CoverageExtraPremiumAmountPRD.FieldName = ''CoverageExtraPremiumAmountPRD''
				AND CoverageExtraPremiumAmountPRD.FloatValue = 0
			WHERE AsRole.RoleCode = ''37''
				AND AsRole.RoleGUID NOT IN 
				(
					SELECT RoleGUID 
					FROM AsRoleField 
					WHERE FieldName = ''CoverageExtraPremiumCommissionCodePRD''
				)
		)
		'; 

	VSQL3:= 
		' 
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
		SELECT RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText
		FROM 
		(
			SELECT *
			FROM 
			(
				SELECT AsRole.RoleGUID AS RoleGUID, ''CoverageExtraPremiumCommissionCodeTRD'' AS FieldName, ''02'' AS FieldTypeCode, AsMapValue.TextValue AS TextValue, 1 AS OptionTextFlag,
					CASE
						WHEN AsMapValue.TextValue = ''CMS'' THEN ''AsCodeExtraPremiumCommissionCode.CMSSD''
						WHEN AsMapValue.TextValue = ''C_N'' THEN ''AsCodeExtraPremiumCommissionCode.C_NSD''
						WHEN AsMapValue.TextValue = ''NCM'' THEN ''AsCodeExtraPremiumCommissionCode.NCMSD''
					END AS OptionText,
					CASE 
						WHEN AsPolicyField.TextValue = ''02'' THEN ''true''
						ELSE ''false''
					END AS ApplicationSubType,
					MapConversionCoverageIndicator.TextValue AS MapConversionValue
				FROM AsRole
				JOIN AsSegment ON AsSegment.SegmentGUID = AsRole.SegmentGUID
				JOIN AsPolicy ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID
				JOIN AsSegmentField InsuranceBasis ON AsRole.SegmentGUID = InsuranceBasis.SegmentGUID
					AND InsuranceBasis.FieldName = ''InsuranceBasis''
				JOIN AsSegmentField CoverageCode ON AsRole.SegmentGUID = CoverageCode.SegmentGUID
					AND CoverageCode.FieldName = ''CoverageCode''
				JOIN AsRoleField ExtraPremiumTypeCode ON AsRole.RoleGUID = ExtraPremiumTypeCode.RoleGUID
					AND ExtraPremiumTypeCode.FieldName = ''CoverageExtraPremiumTypeCodeTRD''
				JOIN AsRoleField CoverageExtraPremiumAmountTRD ON AsRole.RoleGUID = CoverageExtraPremiumAmountTRD.RoleGUID
					AND CoverageExtraPremiumAmountTRD.FieldName = ''CoverageExtraPremiumAmountTRD''
					AND CoverageExtraPremiumAmountTRD.FloatValue != 0
				JOIN AsPolicyField ON AsPolicyField.PolicyGUID = AsPolicy.PolicyGUID
					AND AsPolicyField.FieldName = ''ApplicationSubType''
				JOIN AsMapGroup ON AsMapGroup.MapGroupDescription = ''RISP_CoverageExtraPremiumCommission''
				JOIN AsMapValue ON AsMapValue.MapGroupGUID = AsMapGroup.MapGroupGUID
				JOIN AsMapCriteria MapCoverageCode ON MapCoverageCode.MapValueGUID = AsMapValue.MapValueGUID
					AND MapCoverageCode.MapCriteriaName = ''CoverageCode''
					AND MapCoverageCode.TextValue = CoverageCode.TextValue
				JOIN AsMapCriteria MapInsuranceBasis ON MapInsuranceBasis.MapValueGUID = AsMapValue.MapValueGUID
					AND MapInsuranceBasis.MapCriteriaName = ''InsuranceBasis''
					AND MapInsuranceBasis.TextValue = InsuranceBasis.TextValue
				JOIN AsMapCriteria MapConversionCoverageIndicator ON MapConversionCoverageIndicator.MapValueGUID = AsMapValue.MapValueGUID
					AND MapConversionCoverageIndicator.MapCriteriaName = ''ConversionCoverageIndicator''
				JOIN AsMapCriteria MapExtraPremiumTypeCode ON MapExtraPremiumTypeCode.MapValueGUID = AsMapValue.MapValueGUID
					AND MapExtraPremiumTypeCode.MapCriteriaName = ''ExtraPremiumTypeCode''
					AND MapExtraPremiumTypeCode.TextValue = ExtraPremiumTypeCode.TextValue
				WHERE AsRole.RoleCode = ''37''
					AND AsRole.RoleGUID NOT IN 
					(
						SELECT RoleGUID 
						FROM AsRoleField 
						WHERE FieldName = ''CoverageExtraPremiumCommissionCodeTRD''
					)
			)
			WHERE MapConversionValue = ApplicationSubType
			UNION
			SELECT AsRole.RoleGUID AS RoleGUID, ''CoverageExtraPremiumCommissionCodeTRD'' AS FieldName, ''02'' AS FieldTypeCode, ''00'' AS TextValue, 1 AS OptionTextFlag, ''AsCodeComboNASD'' AS OptionText, ''false'' AS ApplicationSubType, ''false'' AS MapConversionValue
			FROM AsRole
			JOIN AsRoleField CoverageExtraPremiumAmountTRD ON AsRole.RoleGUID = CoverageExtraPremiumAmountTRD.RoleGUID
				AND CoverageExtraPremiumAmountTRD.FieldName = ''CoverageExtraPremiumAmountTRD''
				AND CoverageExtraPremiumAmountTRD.FloatValue = 0
			WHERE AsRole.RoleCode = ''37''
				AND AsRole.RoleGUID NOT IN 
				(
					SELECT RoleGUID 
					FROM AsRoleField 
					WHERE FieldName = ''CoverageExtraPremiumCommissionCodeTRD''
				)
		)
		'; 

	VSQL4:= 
		' 
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue) 
		SELECT AsRole.RoleGUID, ''CoverageExtraPremiumCommissionCutIndicatorPRD'', ''02'', ''UNCHECKED'' 
		FROM AsRole 
		WHERE AsRole.RoleCode = ''37'' 
			AND AsRole.RoleGUID NOT IN ( 
				SELECT RoleGUID  
				FROM AsRoleField  
				WHERE FieldName = ''CoverageExtraPremiumCommissionCutIndicatorPRD'' 
			) 
		'; 

	VSQL5:= 
		' 
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue) 
		SELECT AsRole.RoleGUID, ''CoverageExtraPremiumCommissionCutIndicatorPRP'', ''02'', ''UNCHECKED'' 
		FROM AsRole 
		WHERE AsRole.RoleCode = ''37'' 
			AND AsRole.RoleGUID NOT IN ( 
				SELECT RoleGUID  
				FROM AsRoleField  
				WHERE FieldName = ''CoverageExtraPremiumCommissionCutIndicatorPRP'' 
			) 
		'; 

	VSQL6:= 
		' 
		INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue) 
		SELECT AsRole.RoleGUID, ''CoverageExtraPremiumCommissionCutIndicatorTRD'', ''02'', ''UNCHECKED'' 
		FROM AsRole 
		WHERE AsRole.RoleCode = ''37'' 
			AND AsRole.RoleGUID NOT IN ( 
				SELECT RoleGUID  
				FROM AsRoleField  
				WHERE FieldName = ''CoverageExtraPremiumCommissionCutIndicatorTRD'' 
			) 
		'; 

VRESULT := NULL;

    EXECUTESQL ( VSQL1, VRESULT );
    EXECUTESQL ( VSQL2, VRESULT );
	EXECUTESQL ( VSQL3, VRESULT );
    EXECUTESQL ( VSQL4, VRESULT );
	EXECUTESQL ( VSQL5, VRESULT );
    EXECUTESQL ( VSQL6, VRESULT );

END;
/