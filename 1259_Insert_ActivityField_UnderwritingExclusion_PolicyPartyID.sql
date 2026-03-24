DECLARE 
    VSQL1 VARCHAR2(32767);
    VRESULT VARCHAR2(200);

BEGIN
	-- Insert ActivityField PolicyPartyID in ApplyInsuredUnderwritingExclusion, ChangeCoverageUnderwritingExclusion, ChangeCoverageUnderwritingExclusionAtIssue
	VSQL1:= '
		INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
		SELECT AsActivity.ActivityGUID, ''PolicyPartyID'', ''02'', PolicyPartyID
		FROM AsActivity
		INNER JOIN AsTransaction ON AsActivity.TransactionGUID = AsTransaction.TransactionGUID
			AND AsTransaction.TransactionName IN (''ApplyInsuredUnderwritingExclusion'', ''ChangeCoverageUnderwritingExclusion'', ''ChangeCoverageUnderwritingExclusionAtIssue'')
		INNER JOIN AsActivityField ON AsActivity.ActivityGUID = AsActivityField.ActivityGUID
			AND AsActivityField.FieldName = ''CoverageIdentifier''
		INNER JOIN ( 
			SELECT AsRole.SegmentGUID, MAX(AsClientField.TextValue) AS PolicyPartyID
			FROM AsRole
			INNER JOIN AsClientField ON AsClientField.ClientGUID = AsRole.ClientGUID 
				AND AsClientField.FieldName = ''PolicyPartyID''
			INNER JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsRole.SegmentGUID 
				AND AsSegmentField.FieldName = ''CoverageStatus''
				AND AsSegmentField.TextValue IN (''01'', ''19'', ''02'', ''08'', ''67'', ''79'')
			WHERE AsRole.RoleCode = ''37''
				AND AsRole.StatusCode = ''01''
			GROUP BY AsRole.SegmentGUID
			) PolicyPartyID ON PolicyPartyID.SegmentGUID = AsActivityField.TextValue
		WHERE AsActivity.ActivityGUID NOT IN 
			(
			SELECT DISTINCT(AsActivity.ActivityGUID)
			FROM AsActivity
			JOIN AsActivityField ON AsActivity.ActivityGUID = AsActivityField.ActivityGUID 
				AND AsActivityField.FieldName = ''PolicyPartyID''
			JOIN AsTransaction ON AsActivity.TransactionGUID = AsTransaction.TransactionGUID 
				AND AsTransaction.TransactionName IN (''ApplyInsuredUnderwritingExclusion'', ''ChangeCoverageUnderwritingExclusion'', ''ChangeCoverageUnderwritingExclusionAtIssue'')
			)
		';

VRESULT := NULL;

EXECUTESQL ( VSQL1, VRESULT );

END;
/