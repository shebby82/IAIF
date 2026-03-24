DECLARE 
    VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);

    VRESULT VARCHAR2(200);

BEGIN

	-- Insert ActivityField CurrentPreferredUnderwriting in ReinsuranceAdjustRiskCession
	VSQL1:='
		INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
		SELECT AsActivity.ActivityGUID, ''CurrentPreferredUnderwriting'', ''02'', ''N_A''
		FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
			AND TransactionName = ''ReinsuranceAdjustRiskCession''
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT AsActivity.ActivityGUID 
			FROM AsActivity 
			JOIN AsActivityField ON AsActivityField.ActivityGUID=AsActivity.ActivityGUID 
				AND AsActivityField.FieldName = ''CurrentPreferredUnderwriting''
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
				AND TransactionName = ''ReinsuranceAdjustRiskCession''
			)
			';

	-- Insert ActivityField NewPreferredUnderwriting in ReinsuranceAdjustRiskCession
	VSQL2:='
		INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
		SELECT AsActivity.ActivityGUID, ''NewPreferredUnderwriting'', ''02'', ''N_A''
		FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
			AND TransactionName = ''ReinsuranceAdjustRiskCession''
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT AsActivity.ActivityGUID 
			FROM AsActivity 
			JOIN AsActivityField ON AsActivityField.ActivityGUID=AsActivity.ActivityGUID 
				AND AsActivityField.FieldName = ''NewPreferredUnderwriting''
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
				AND TransactionName = ''ReinsuranceAdjustRiskCession''
			)
			';
			
VRESULT := NULL;

    EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );
    
END;
/