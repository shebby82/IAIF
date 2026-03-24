DECLARE
    v_existing_rows   NUMBER := 0;
    v_affected_rows NUMBER := 0;
    v_operation_type  VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'GetPolicyTransaction';
    v_application_name VARCHAR2(50) := 'Modernia';
    v_version_number NUMBER := 7;

    v_query_value CLOB := '
	SELECT 
		AsTransaction.TransactionName,
		AsTransaction.TransactionGUID,
		TO_CHAR(AsActivity.EffectiveDate, ''YYYY-MM-DD'') EFFECTIVEDATE,
		TO_CHAR(AsActivity.ActiveFromDate, ''YYYY-MM-DD'') PROCESSEDDATE,
		AsActivity.ClientNumber,
		AsPolicy.PolicyNumber,
		TranslationAsCodeStatus.TranslationValue POLICYSTATUS,
		TranslationAsCodeSubstatus.TranslationValue POLICYSUBSTATUS,
		CoverageIdentifier.TextValue COVERAGEIDENTIFIER,
		CoverageCode.TextValue COVERAGECODE,
		CoverageVersion.TextValue COVERAGEVERSION,
		CoverageVersionCode.TextValue COVERAGEVERSIONCODE,
		InsuranceBasis.TextValue INSURANCEBASIS,
		TO_CHAR(CoverageEffectiveDate.DateValue, ''YYYY-MM-DD'') COVERAGEEFFECTIVEDATE,
		InsuredPartyID.TextValue INSUREDPARTYID,
		InsuredPolicyPartyID.TextValue INSUREDPOLICYPARTYID,
		CASE
			WHEN PolicyTerminationAsCodeComboBlank.CodeValue IS NOT NULL  THEN TranslationPolicyTerminationAsCodeComboBlank.TranslationValue
			WHEN PolicyTerminationAsCodeTerminationReason.CodeValue IS NOT NULL  THEN TranslationPolicyTerminationAsCodeTerminationReason.TranslationValue
		END TRANSACTIONREASON
	FROM AsPolicy
	JOIN AsActivity	ON AsActivity.PolicyGUID = AsPolicy.PolicyGUID
	   AND AsActivity.TypeCode IN (''01'', ''04'')
	   AND AsActivity.StatusCode = ''01''
	JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
        AND AsTransaction.TransactionName = ''TerminatePolicy''
	JOIN AsSegment ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID
	JOIN AsCode AsCodeStatus ON AsCodeStatus.CodeValue = AsPolicy.StatusCode
	   AND AsCodeStatus.CodeName  = ''AsCodeStatus''
	JOIN AsTranslation TranslationAsCodeStatus ON TranslationAsCodeStatus.TranslationKey = AsCodeStatus.ShortDescription
	   AND TranslationAsCodeStatus.Locale = ''en-CA''
	JOIN AsPolicyField	ON AsPolicyField.PolicyGUID = AsPolicy.PolicyGUID
	   AND AsPolicyField.FieldName  = ''PolicySubstatus''
	JOIN AsCode AsCodeSubstatus ON AsCodeSubstatus.CodeValue = AsPolicyField.TextValue
	   AND AsCodeSubstatus.CodeName  = ''AsCodeSubstatus''
	JOIN AsTranslation TranslationAsCodeSubstatus ON TranslationAsCodeSubstatus.TranslationKey = AsCodeSubstatus.ShortDescription
	   AND TranslationAsCodeSubstatus.Locale = ''en-CA''
	JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageIdentifier.FieldName = ''CoverageIdentifier''
	JOIN AsSegmentField CoverageCode ON CoverageCode.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageCode.FieldName = ''CoverageCode''
	JOIN AsSegmentField CoverageEffectiveDate ON CoverageEffectiveDate.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageEffectiveDate.FieldName  = ''CoverageEffectiveDate''
	JOIN AsSegmentField CoverageVersion	ON CoverageVersion.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageVersion.FieldName  = ''CoverageVersion''
	JOIN AsSegmentField CoverageVersionCode	ON CoverageVersionCode.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageVersionCode.FieldName = ''CoverageVersionCode''
	JOIN AsSegmentField InsuranceBasis ON InsuranceBasis.SegmentGUID = AsSegment.SegmentGUID
	   AND InsuranceBasis.FieldName  = ''InsuranceBasis''
	JOIN AsSegmentField CoverageTerminationDate ON CoverageTerminationDate.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageTerminationDate.FieldName  = ''CoverageTerminationDate''
       AND (CoverageTerminationDate.DateValue IS NULL OR (CoverageTerminationDate.DateValue IS NOT NULL AND CoverageTerminationDate.DateValue = AsActivity.EffectiveDate))
	JOIN AsRole InsuredRole ON InsuredRole.SegmentGUID = AsSegment.SegmentGUID
	   AND InsuredRole.RoleCode   = ''37''
       AND InsuredRole.StatusCode = ''01''
	JOIN AsClientField InsuredPartyID ON InsuredPartyID.ClientGUID = InsuredRole.ClientGUID
	   AND InsuredPartyID.FieldName  = ''PartyID''
	JOIN AsClientField InsuredPolicyPartyID	ON InsuredPolicyPartyID.ClientGUID = InsuredRole.ClientGUID
	   AND InsuredPolicyPartyID.FieldName  = ''PolicyPartyID''
	JOIN AsActivityField PolicyTerminationReason ON PolicyTerminationReason.ActivityGUID = AsActivity.ActivityGUID
	   AND PolicyTerminationReason.FieldName = ''PolicyTerminationReason''
	LEFT JOIN AsCode PolicyTerminationAsCodeComboBlank ON PolicyTerminationAsCodeComboBlank.CodeValue = PolicyTerminationReason.TextValue
	   AND PolicyTerminationAsCodeComboBlank.CodeName  = ''AsCodeComboBlank''
	LEFT JOIN AsTranslation TranslationPolicyTerminationAsCodeComboBlank ON TranslationPolicyTerminationAsCodeComboBlank.TranslationKey = PolicyTerminationAsCodeComboBlank.ShortDescription
	   AND TranslationPolicyTerminationAsCodeComboBlank.Locale = ''en-CA''
	LEFT JOIN AsCode PolicyTerminationAsCodeTerminationReason ON PolicyTerminationAsCodeTerminationReason.CodeValue = PolicyTerminationReason.TextValue
	   AND PolicyTerminationAsCodeTerminationReason.CodeName = ''AsCodeTerminationReason''
	LEFT JOIN AsTranslation TranslationPolicyTerminationAsCodeTerminationReason	ON TranslationPolicyTerminationAsCodeTerminationReason.TranslationKey = PolicyTerminationAsCodeTerminationReason.ShortDescription
	   AND TranslationPolicyTerminationAsCodeTerminationReason.Locale = ''en-CA''
	WHERE
		(
			(
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]'',
					''[Transact2]'',
					''[Transact3]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]'',
					''[Transact2]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]'',
					''[Transact3]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact2]'',
					''[Transact3]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NULL
				AND TRIM(''[Transact3]'') IS NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NULL
				AND AsTransaction.TransactionName IN (
					''[Transact2]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NULL
				AND TRIM(''[Transact2]'') IS NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact3]''
					)
				)
		)
		AND (
			TRIM(''[ActFromDate]'') IS NULL
			OR (
				TRIM(''[ActFromDate]'') IS NOT NULL
				AND TO_DATE(''[ActFromDate]'',''YYYY-MM-DD'') <= (
					SELECT TRUNC(SystemDate)
					FROM AsSystemDate
					WHERE CurrentIndicator = ''Y''
				)
				AND TRUNC(AsActivity.EffectiveDate) >= TO_DATE(''[ActFromDate]'',''YYYY-MM-DD'')
			)
		)
		AND (
			(TRIM(''[PartyID1]'')  IS NULL
			AND TRIM(''[PartyID2]'')  IS NULL
			AND TRIM(''[PartyID3]'')  IS NULL
			AND TRIM(''[PartyID4]'')  IS NULL
			AND TRIM(''[PartyID5]'')  IS NULL
			AND TRIM(''[PartyID6]'')  IS NULL
			AND TRIM(''[PartyID7]'')  IS NULL
			AND TRIM(''[PartyID8]'')  IS NULL
			AND TRIM(''[PartyID9]'')  IS NULL
			AND TRIM(''[PartyID10]'') IS NULL
			)
			OR InsuredPartyID.TextValue IN (
				''[PartyID1]'',''[PartyID2]'',''[PartyID3]'',
				''[PartyID4]'',''[PartyID5]'',''[PartyID6]'',
				''[PartyID7]'',''[PartyID8]'',''[PartyID9]'',
				''[PartyID10]''
			)
		)
		AND (
			TRIM(''[PolicyNumber]'') IS NULL
			OR (AsPolicy.SystemCode = ''01'' AND AsPolicy.PolicyNumber IN (''[PolicyNumber]'') )
		)
        
UNION

	SELECT 
		AsTransaction.TransactionName,
		AsTransaction.TransactionGUID,
		TO_CHAR(AsActivity.EffectiveDate, ''YYYY-MM-DD'') EFFECTIVEDATE,
		TO_CHAR(AsActivity.ActiveFromDate, ''YYYY-MM-DD'') PROCESSEDDATE,
		AsActivity.ClientNumber,
		AsPolicy.PolicyNumber,
		TranslationAsCodeStatus.TranslationValue POLICYSTATUS,
		TranslationAsCodeSubstatus.TranslationValue POLICYSUBSTATUS,
		CoverageIdentifier.TextValue COVERAGEIDENTIFIER,
		CoverageCode.TextValue COVERAGECODE,
		CoverageVersion.TextValue COVERAGEVERSION,
		CoverageVersionCode.TextValue COVERAGEVERSIONCODE,
		InsuranceBasis.TextValue INSURANCEBASIS,
		TO_CHAR(CoverageEffectiveDate.DateValue, ''YYYY-MM-DD'') COVERAGEEFFECTIVEDATE,
		InsuredPartyID.TextValue INSUREDPARTYID,
		InsuredPolicyPartyID.TextValue INSUREDPOLICYPARTYID,
		CASE
			WHEN CoverageTerminationAsCodeComboNA.CodeValue IS NOT NULL  THEN TranslationCoverageTerminationAsCodeComboNA.TranslationValue
			WHEN CoverageTerminationAsCodeTerminationReason.CodeValue IS NOT NULL  THEN TranslationCoverageTerminationAsCodeTerminationReason.TranslationValue
		END TRANSACTIONREASON
	FROM AsPolicy
	JOIN AsActivity	ON AsActivity.PolicyGUID = AsPolicy.PolicyGUID
	   AND AsActivity.TypeCode IN (''01'', ''04'')
	   AND AsActivity.StatusCode = ''01''
	JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
        AND AsTransaction.TransactionName = ''TerminateCoverage''
	JOIN AsSegment ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID
	JOIN AsCode AsCodeStatus ON AsCodeStatus.CodeValue = AsPolicy.StatusCode
	   AND AsCodeStatus.CodeName  = ''AsCodeStatus''
	JOIN AsTranslation TranslationAsCodeStatus ON TranslationAsCodeStatus.TranslationKey = AsCodeStatus.ShortDescription
	   AND TranslationAsCodeStatus.Locale = ''en-CA''
	JOIN AsPolicyField	ON AsPolicyField.PolicyGUID = AsPolicy.PolicyGUID
	   AND AsPolicyField.FieldName  = ''PolicySubstatus''
	JOIN AsCode AsCodeSubstatus ON AsCodeSubstatus.CodeValue = AsPolicyField.TextValue
	   AND AsCodeSubstatus.CodeName  = ''AsCodeSubstatus''
	JOIN AsTranslation TranslationAsCodeSubstatus ON TranslationAsCodeSubstatus.TranslationKey = AsCodeSubstatus.ShortDescription
	   AND TranslationAsCodeSubstatus.Locale = ''en-CA''
	JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageIdentifier.FieldName = ''CoverageIdentifier''
	JOIN AsSegmentField CoverageCode ON CoverageCode.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageCode.FieldName = ''CoverageCode''
	JOIN AsSegmentField CoverageEffectiveDate ON CoverageEffectiveDate.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageEffectiveDate.FieldName  = ''CoverageEffectiveDate''
	JOIN AsSegmentField CoverageVersion	ON CoverageVersion.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageVersion.FieldName  = ''CoverageVersion''
	JOIN AsSegmentField CoverageVersionCode	ON CoverageVersionCode.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageVersionCode.FieldName = ''CoverageVersionCode''
	JOIN AsSegmentField InsuranceBasis ON InsuranceBasis.SegmentGUID = AsSegment.SegmentGUID
	   AND InsuranceBasis.FieldName  = ''InsuranceBasis''
	JOIN AsSegmentField CoverageTerminationDate ON CoverageTerminationDate.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageTerminationDate.FieldName  = ''CoverageTerminationDate''
       AND (CoverageTerminationDate.DateValue IS NULL OR (CoverageTerminationDate.DateValue IS NOT NULL AND CoverageTerminationDate.DateValue = AsActivity.EffectiveDate))
	JOIN AsRole InsuredRole ON InsuredRole.SegmentGUID = AsSegment.SegmentGUID
	   AND InsuredRole.RoleCode   = ''37''
       AND InsuredRole.StatusCode = ''01''
	JOIN AsClientField InsuredPartyID ON InsuredPartyID.ClientGUID = InsuredRole.ClientGUID
	   AND InsuredPartyID.FieldName  = ''PartyID''
	JOIN AsClientField InsuredPolicyPartyID	ON InsuredPolicyPartyID.ClientGUID = InsuredRole.ClientGUID
	   AND InsuredPolicyPartyID.FieldName  = ''PolicyPartyID''
	JOIN AsActivityField CoverageTerminationReason	ON CoverageTerminationReason.ActivityGUID = AsActivity.ActivityGUID
	   AND CoverageTerminationReason.FieldName = ''CoverageTerminationReason''
    JOIN AsActivityField CoverageTerminationIdentifier ON CoverageTerminationIdentifier.ActivityGUID = CoverageTerminationReason.ActivityGUID
	   AND CoverageTerminationIdentifier.FieldName = ''CoverageIdentifier''
       AND CoverageTerminationIdentifier.TextValue = CoverageIdentifier.SegmentGUID
	LEFT JOIN AsCode CoverageTerminationAsCodeComboNA ON CoverageTerminationAsCodeComboNA.CodeValue = CoverageTerminationReason.TextValue
	   AND CoverageTerminationAsCodeComboNA.CodeName  = ''AsCodeComboNA''
	LEFT JOIN AsTranslation TranslationCoverageTerminationAsCodeComboNA ON TranslationCoverageTerminationAsCodeComboNA.TranslationKey = CoverageTerminationAsCodeComboNA.ShortDescription
	   AND TranslationCoverageTerminationAsCodeComboNA.Locale = ''en-CA''
	LEFT JOIN AsCode CoverageTerminationAsCodeTerminationReason ON CoverageTerminationAsCodeTerminationReason.CodeValue = CoverageTerminationReason.TextValue
	   AND CoverageTerminationAsCodeTerminationReason.CodeName  = ''AsCodeTerminationReason''
	LEFT JOIN AsTranslation TranslationCoverageTerminationAsCodeTerminationReason ON TranslationCoverageTerminationAsCodeTerminationReason.TranslationKey = CoverageTerminationAsCodeTerminationReason.ShortDescription
	   AND TranslationCoverageTerminationAsCodeTerminationReason.Locale = ''en-CA''
	WHERE
		(
			(
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]'',
					''[Transact2]'',
					''[Transact3]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]'',
					''[Transact2]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]'',
					''[Transact3]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact2]'',
					''[Transact3]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NULL
				AND TRIM(''[Transact3]'') IS NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NULL
				AND AsTransaction.TransactionName IN (
					''[Transact2]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NULL
				AND TRIM(''[Transact2]'') IS NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact3]''
					)
				)
		)
		AND (
			TRIM(''[ActFromDate]'') IS NULL
			OR (
				TRIM(''[ActFromDate]'') IS NOT NULL
				AND TO_DATE(''[ActFromDate]'',''YYYY-MM-DD'') <= (
					SELECT TRUNC(SystemDate)
					FROM AsSystemDate
					WHERE CurrentIndicator = ''Y''
				)
				AND TRUNC(AsActivity.EffectiveDate) >= TO_DATE(''[ActFromDate]'',''YYYY-MM-DD'')
			)
		)
		AND (
			(TRIM(''[PartyID1]'')  IS NULL
			AND TRIM(''[PartyID2]'')  IS NULL
			AND TRIM(''[PartyID3]'')  IS NULL
			AND TRIM(''[PartyID4]'')  IS NULL
			AND TRIM(''[PartyID5]'')  IS NULL
			AND TRIM(''[PartyID6]'')  IS NULL
			AND TRIM(''[PartyID7]'')  IS NULL
			AND TRIM(''[PartyID8]'')  IS NULL
			AND TRIM(''[PartyID9]'')  IS NULL
			AND TRIM(''[PartyID10]'') IS NULL
			)
			OR InsuredPartyID.TextValue IN (
				''[PartyID1]'',''[PartyID2]'',''[PartyID3]'',
				''[PartyID4]'',''[PartyID5]'',''[PartyID6]'',
				''[PartyID7]'',''[PartyID8]'',''[PartyID9]'',
				''[PartyID10]''
			)
		)
		AND (
			TRIM(''[PolicyNumber]'') IS NULL
			OR (AsPolicy.SystemCode = ''01'' AND AsPolicy.PolicyNumber IN (''[PolicyNumber]'') )
		)
        
UNION

	SELECT 
		AsTransaction.TransactionName,
		AsTransaction.TransactionGUID,
		TO_CHAR(AsActivity.EffectiveDate, ''YYYY-MM-DD'') EFFECTIVEDATE,
		TO_CHAR(AsActivity.ActiveFromDate, ''YYYY-MM-DD'') PROCESSEDDATE,
		AsActivity.ClientNumber,
		AsPolicy.PolicyNumber,
		TranslationAsCodeStatus.TranslationValue POLICYSTATUS,
		TranslationAsCodeSubstatus.TranslationValue POLICYSUBSTATUS,
		CoverageIdentifier.TextValue COVERAGEIDENTIFIER,
		CoverageCode.TextValue COVERAGECODE,
		CoverageVersion.TextValue COVERAGEVERSION,
		CoverageVersionCode.TextValue COVERAGEVERSIONCODE,
		InsuranceBasis.TextValue INSURANCEBASIS,
		TO_CHAR(CoverageEffectiveDate.DateValue, ''YYYY-MM-DD'') COVERAGEEFFECTIVEDATE,
		InsuredPartyID.TextValue INSUREDPARTYID,
		InsuredPolicyPartyID.TextValue INSUREDPOLICYPARTYID,
		CASE
			WHEN CoverageReductionAsCodeComboNA.CodeValue IS NOT NULL  THEN TranslationCoverageReductionAsCodeComboNA.TranslationValue
			WHEN CoverageReductionAsCodeReduceFaceAmountReason.CodeValue IS NOT NULL THEN TranslationCoverageReductionAsCodeReduceFaceAmountReason.TranslationValue
		END TRANSACTIONREASON
	FROM AsPolicy
	JOIN AsActivity	ON AsActivity.PolicyGUID = AsPolicy.PolicyGUID
	   AND AsActivity.TypeCode IN (''01'', ''04'')
	   AND AsActivity.StatusCode = ''01''
	JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
        AND AsTransaction.TransactionName = ''ReduceCoverageFaceAmount''
	JOIN AsSegment ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID
	JOIN AsCode AsCodeStatus ON AsCodeStatus.CodeValue = AsPolicy.StatusCode
	   AND AsCodeStatus.CodeName  = ''AsCodeStatus''
	JOIN AsTranslation TranslationAsCodeStatus ON TranslationAsCodeStatus.TranslationKey = AsCodeStatus.ShortDescription
	   AND TranslationAsCodeStatus.Locale = ''en-CA''
	JOIN AsPolicyField	ON AsPolicyField.PolicyGUID = AsPolicy.PolicyGUID
	   AND AsPolicyField.FieldName  = ''PolicySubstatus''
	JOIN AsCode AsCodeSubstatus ON AsCodeSubstatus.CodeValue = AsPolicyField.TextValue
	   AND AsCodeSubstatus.CodeName  = ''AsCodeSubstatus''
	JOIN AsTranslation TranslationAsCodeSubstatus ON TranslationAsCodeSubstatus.TranslationKey = AsCodeSubstatus.ShortDescription
	   AND TranslationAsCodeSubstatus.Locale = ''en-CA''
	JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageIdentifier.FieldName = ''CoverageIdentifier''
	JOIN AsSegmentField CoverageCode ON CoverageCode.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageCode.FieldName = ''CoverageCode''
	JOIN AsSegmentField CoverageEffectiveDate ON CoverageEffectiveDate.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageEffectiveDate.FieldName  = ''CoverageEffectiveDate''
	JOIN AsSegmentField CoverageVersion	ON CoverageVersion.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageVersion.FieldName  = ''CoverageVersion''
	JOIN AsSegmentField CoverageVersionCode	ON CoverageVersionCode.SegmentGUID = AsSegment.SegmentGUID
	   AND CoverageVersionCode.FieldName = ''CoverageVersionCode''
	JOIN AsSegmentField InsuranceBasis ON InsuranceBasis.SegmentGUID = AsSegment.SegmentGUID
	   AND InsuranceBasis.FieldName  = ''InsuranceBasis''
	JOIN AsRole InsuredRole ON InsuredRole.SegmentGUID = AsSegment.SegmentGUID
	   AND InsuredRole.RoleCode   = ''37''
       AND InsuredRole.StatusCode = ''01''
	JOIN AsClientField InsuredPartyID ON InsuredPartyID.ClientGUID = InsuredRole.ClientGUID
	   AND InsuredPartyID.FieldName  = ''PartyID''
	JOIN AsClientField InsuredPolicyPartyID	ON InsuredPolicyPartyID.ClientGUID = InsuredRole.ClientGUID
	   AND InsuredPolicyPartyID.FieldName  = ''PolicyPartyID''
	JOIN AsActivityField CoverageReductionReason ON CoverageReductionReason.ActivityGUID = AsActivity.ActivityGUID
	   AND CoverageReductionReason.FieldName = ''CoverageReductionReason''
    JOIN AsActivityField CoverageReductionIdentifier ON CoverageReductionIdentifier.ActivityGUID = CoverageReductionReason.ActivityGUID
	   AND CoverageReductionIdentifier.FieldName = ''CoverageIdentifier''
       AND CoverageReductionIdentifier.TextValue = CoverageIdentifier.SegmentGUID
	LEFT JOIN AsCode CoverageReductionAsCodeComboNA	ON CoverageReductionAsCodeComboNA.CodeValue = CoverageReductionReason.TextValue
	   AND CoverageReductionAsCodeComboNA.CodeName = ''AsCodeComboNA''
	LEFT JOIN AsTranslation TranslationCoverageReductionAsCodeComboNA ON TranslationCoverageReductionAsCodeComboNA.TranslationKey = CoverageReductionAsCodeComboNA.ShortDescription
	   AND TranslationCoverageReductionAsCodeComboNA.Locale = ''en-CA''
	LEFT JOIN AsCode CoverageReductionAsCodeReduceFaceAmountReason ON CoverageReductionAsCodeReduceFaceAmountReason.CodeValue = CoverageReductionReason.TextValue
	   AND CoverageReductionAsCodeReduceFaceAmountReason.CodeName  = ''AsCodeReduceFaceAmountReason''
	LEFT JOIN AsTranslation TranslationCoverageReductionAsCodeReduceFaceAmountReason ON TranslationCoverageReductionAsCodeReduceFaceAmountReason.TranslationKey = CoverageReductionAsCodeReduceFaceAmountReason.ShortDescription
	   AND TranslationCoverageReductionAsCodeReduceFaceAmountReason.Locale = ''en-CA''
	WHERE
		(
			(
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]'',
					''[Transact2]'',
					''[Transact3]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]'',
					''[Transact2]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]'',
					''[Transact3]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact2]'',
					''[Transact3]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NOT NULL
				AND TRIM(''[Transact2]'') IS NULL
				AND TRIM(''[Transact3]'') IS NULL
				AND AsTransaction.TransactionName IN (
					''[Transact1]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NULL
				AND TRIM(''[Transact2]'') IS NOT NULL
				AND TRIM(''[Transact3]'') IS NULL
				AND AsTransaction.TransactionName IN (
					''[Transact2]''
					)
				)
			OR (
				TRIM(''[Transact1]'') IS NULL
				AND TRIM(''[Transact2]'') IS NULL
				AND TRIM(''[Transact3]'') IS NOT NULL
				AND AsTransaction.TransactionName IN (
					''[Transact3]''
					)
				)
		)
		AND (
			TRIM(''[ActFromDate]'') IS NULL
			OR (
				TRIM(''[ActFromDate]'') IS NOT NULL
				AND TO_DATE(''[ActFromDate]'',''YYYY-MM-DD'') <= (
					SELECT TRUNC(SystemDate)
					FROM AsSystemDate
					WHERE CurrentIndicator = ''Y''
				)
				AND TRUNC(AsActivity.EffectiveDate) >= TO_DATE(''[ActFromDate]'',''YYYY-MM-DD'')
			)
		)
		AND (
			(TRIM(''[PartyID1]'')  IS NULL
			AND TRIM(''[PartyID2]'')  IS NULL
			AND TRIM(''[PartyID3]'')  IS NULL
			AND TRIM(''[PartyID4]'')  IS NULL
			AND TRIM(''[PartyID5]'')  IS NULL
			AND TRIM(''[PartyID6]'')  IS NULL
			AND TRIM(''[PartyID7]'')  IS NULL
			AND TRIM(''[PartyID8]'')  IS NULL
			AND TRIM(''[PartyID9]'')  IS NULL
			AND TRIM(''[PartyID10]'') IS NULL
			)
			OR InsuredPartyID.TextValue IN (
				''[PartyID1]'',''[PartyID2]'',''[PartyID3]'',
				''[PartyID4]'',''[PartyID5]'',''[PartyID6]'',
				''[PartyID7]'',''[PartyID8]'',''[PartyID9]'',
				''[PartyID10]''
			)
		)
		AND (
			TRIM(''[PolicyNumber]'') IS NULL
			OR (AsPolicy.SystemCode = ''01'' AND AsPolicy.PolicyNumber IN (''[PolicyNumber]'') )
		)
	';


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
        INSERT INTO AsRestServiceQuery (RestServiceQueryGUID, QueryName, VersionNumber, QueryValue, ApplicationName)
        VALUES (NEWID(), v_query_name, v_version_number, v_query_value, v_application_name);

        v_operation_type := 'inserted';
    END IF;
    
    v_affected_rows := SQL%ROWCOUNT;

    -- Output the operation type and affected rows
    DBMS_OUTPUT.PUT_LINE(v_affected_rows || ' row(s) ' || v_operation_type || '.' );
END;
/