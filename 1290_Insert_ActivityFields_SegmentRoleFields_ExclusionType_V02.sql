DECLARE 
    VSQL1 VARCHAR2(32767);
    VSQL2 VARCHAR2(32767);
    VSQL3 VARCHAR2(32767);
    VSQL4 VARCHAR2(32767);
    VSQL5 VARCHAR2(32767);
    VSQL6 VARCHAR2(32767);
    -- VSQL7 VARCHAR2(32767);
    -- VSQL8 VARCHAR2(32767);
	-- VSQL9 VARCHAR2(32767);
    VRESULT VARCHAR2(200); 
    
    BEGIN
    
    -- Insert empty ExclusionType in AsRoleField for all policies
    VSQL1:='
        INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
        SELECT AsRole.RoleGUID, ''ExclusionType'', ''02'', ''00'', 1, ''AsCodeComboNALD''
        FROM AsRole
		WHERE AsRole.RoleCode = ''37''
			AND AsRole.RoleGUID NOT IN (
					SELECT RoleGUID
					FROM AsRoleField
					WHERE FieldName = ''ExclusionType''
				)';
    
    -- Insert UnderwritingExclusionIndicator for activities
    VSQL2:='
        INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
        SELECT AsActivity.ActivityGUID, ''UnderwritingExclusionIndicator'', ''02'', ''CHECKED''
        FROM AsActivity
		JOIN AsActivityField UnderwritingExclusionChange ON UnderwritingExclusionChange.ActivityGUID = AsActivity.ActivityGUID
			AND UnderwritingExclusionChange.FieldName = ''UnderwritingExclusionChange''
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''ApplyInsuredUnderwritingExclusion'',''ChangeCoverageUnderwritingExclusionAtIssue'',''ChangeCoverageUnderwritingExclusion'')
		WHERE UnderwritingExclusionChange.TextValue IN (''02'',''03'')
			AND AsActivity.ActivityGUID NOT IN (
					SELECT ActivityGUID
					FROM AsActivityField
					WHERE FieldName = ''UnderwritingExclusionIndicator''
				)';
	
    VSQL3:='
        INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
        SELECT AsActivity.ActivityGUID, ''UnderwritingExclusionIndicator'', ''02'', ''UNCHECKED''
        FROM AsActivity
		JOIN AsActivityField UnderwritingExclusionChange ON UnderwritingExclusionChange.ActivityGUID = AsActivity.ActivityGUID
			AND UnderwritingExclusionChange.FieldName = ''UnderwritingExclusionChange''
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''ApplyInsuredUnderwritingExclusion'',''ChangeCoverageUnderwritingExclusionAtIssue'',''ChangeCoverageUnderwritingExclusion'')
		WHERE UnderwritingExclusionChange.TextValue IN (''01'')
			AND AsActivity.ActivityGUID NOT IN (
					SELECT ActivityGUID
					FROM AsActivityField
					WHERE FieldName = ''UnderwritingExclusionIndicator''
				)';

    VSQL4:='
        INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
        SELECT AsActivity.ActivityGUID, ''ExclusionType'', ''02'', ''00'', 1, ''AsCodeComboNALD''
        FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''ApplyInsuredUnderwritingExclusion'',''ChangeCoverageUnderwritingExclusionAtIssue'',''ChangeCoverageUnderwritingExclusion'')
		WHERE AsActivity.ActivityGUID NOT IN (
				SELECT ActivityGUID
				FROM AsActivityField
				WHERE FieldName = ''ExclusionType''
			)';
			
	-- Update PolicyPartyID to PartyID for activities
	VSQL5:='
        INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
        SELECT AsActivity.ActivityGUID, ''PartyID'', ''02'', ClientPartyID.TextValue
        FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''ApplyInsuredUnderwritingExclusion'',''ChangeCoverageUnderwritingExclusionAtIssue'',''ChangeCoverageUnderwritingExclusion'')
		JOIN AsActivityField ActivityPolicyPartyID ON ActivityPolicyPartyID.ActivityGUID = AsActivity.ActivityGUID
			AND ActivityPolicyPartyID.FieldName = ''PolicyPartyID''
        JOIN AsActivityField ActivityCoverageIdentifier ON ActivityCoverageIdentifier.ActivityGUID = AsActivity.ActivityGUID
            AND ActivityCoverageIdentifier.FieldName = ''CoverageIdentifier''
		JOIN AsClientField ClientPolicyPartyID ON ClientPolicyPartyID.TextValue = ActivityPolicyPartyID.TextValue
			AND ClientPolicyPartyID.FieldName = ''PolicyPartyID''
		JOIN AsClient ON AsClient.ClientGUID = ClientPolicyPartyID.ClientGUID
        JOIN AsRole ON AsRole.ClientGUID = AsClient.ClientGUID
            AND AsRole.RoleCode = ''37''
           AND AsRole.StatusCode = ''01''
        JOIN AsSegment ON AsSegment.SegmentGUID = AsRole.SegmentGUID
            AND AsSegment.PolicyGUID = AsActivity.PolicyGUID
            AND AsSegment.SegmentGUID = ActivityCoverageIdentifier.TextValue
		JOIN AsClientField ClientPartyID ON ClientPartyID.ClientGUID = AsClient.ClientGUID
			AND ClientPartyID.FieldName = ''PartyID''
		WHERE AsActivity.ActivityGUID NOT IN (
				SELECT ActivityGUID
				FROM AsActivityField
				WHERE FieldName = ''PartyID''
			)';
	
	VSQL6:=
		'
		DELETE FROM AsActivityField
		WHERE AsActivityField.FieldName = ''PolicyPartyID''
			AND AsActivityField.FieldTypeCode = ''02''
			AND ActivityGUID IN (
				SELECT AsActivity.ActivityGUID
				FROM AsActivity
				JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
					AND AsTransaction.TransactionName IN (''ApplyInsuredUnderwritingExclusion'',''ChangeCoverageUnderwritingExclusionAtIssue'',''ChangeCoverageUnderwritingExclusion'')
			)
		';

    -- We need to pull a list of policies in PROD with UnderwritingExclusionIndicator equals to CHECKED and iA will need to decide the values
		/*
			SELECT DISTINCT AsRole.RoleGUID,
				AsPolicy.PolicyGUID,
				AsPolicy.PolicyNumber,
				AsSegment.SegmentGUID,
				CoverageIdentifier.TextValue CoverageIdentifier,
				Replace(Replace(AsCodeCoverageStatus.LongDescription,'AsCodeCoverageStatus.'),'LD') CoverageStatus,
				'Insured',
				PartyID.TextValue PartyID,
				AsClient.FirstName + ' ' + AsClient.LastName,
				Replace(Replace(AsCodeRoleStatus.LongDescription,'AsCodeRoleStatus.'),'LD') RoleStatus,
				UnderwritingExclusionIndicator.TextValue UnderwritingExclusionIndicator
			FROM AsPolicy
			JOIN AsSegment ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID
			JOIN AsSegmentField CoverageStatus ON CoverageStatus.SegmentGUID = AsSegment.SegmentGUID
				AND CoverageStatus.FieldName = 'CoverageStatus'
			JOIN AsCode AsCodeCoverageStatus ON AsCodeCoverageStatus.CodeValue = CoverageStatus.TextValue
				AND AsCodeCoverageStatus.CodeName = 'AsCodeCoverageStatus'
			JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID
				AND CoverageIdentifier.FieldName = 'CoverageIdentifier'
			JOIN AsRole ON AsRole.SegmentGUID = AsSegment.SegmentGUID 
				AND AsRole.RoleCode IN ('37')
			JOIN AsClient ON AsClient.ClientGUID = AsRole.ClientGUID
			JOIN AsClientField PartyID ON PartyID.ClientGUID = AsClient.ClientGUID 
				AND PartyID.FieldName = 'PartyID'
			JOIN AsCode AsCodeRoleStatus ON AsCodeRoleStatus.CodeValue = AsRole.StatusCode
				AND AsCodeRoleStatus.CodeName = 'AsCodeRoleStatus'
			JOIN AsRoleField UnderwritingExclusionIndicator ON UnderwritingExclusionIndicator.RoleGUID = AsRole.RoleGUID
			WHERE UnderwritingExclusionIndicator.TextValue = 'CHECKED'
		*/
			
	-- Once values determined, below query will need to be UPDATE with actual RoleGUID
		/*
		VSQL7:='
			UPDATE AsRoleField
			SET textValue = '01'
			WHERE FieldName = 'ExclusionType'
				AND RoleGUID IN(
				
				)';
		
		VSQL8:='
			UPDATE AsRoleField
			SET textValue = '02'
			WHERE FieldName = 'ExclusionType'
				AND RoleGUID IN(
				
				)';
			
		VSQL9:='
			UPDATE AsRoleField
			SET textValue = '03'
			WHERE FieldName = 'ExclusionType'
				AND RoleGUID IN(
				
				)';
		*/
	
	
	
    VRESULT := NULL;
    EXECUTESQL ( VSQL1, VRESULT );
    EXECUTESQL ( VSQL2, VRESULT );
    EXECUTESQL ( VSQL3, VRESULT );
    EXECUTESQL ( VSQL4, VRESULT );
    EXECUTESQL ( VSQL5, VRESULT );
    EXECUTESQL ( VSQL6, VRESULT );
    --EXECUTESQL ( VSQL7, VRESULT );
    --EXECUTESQL ( VSQL8, VRESULT );
    --EXECUTESQL ( VSQL9, VRESULT );

END;
/