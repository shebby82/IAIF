BEGIN
    INSERT INTO AsActivityMultiValueField (ActivityGUID, FieldIndex, FieldName, FieldTypeCode, TextValue)
	SELECT AsActivity.ActivityGUID, AsActivityMultiValueField.FieldIndex, 'ReinsuranceFacSplitCessionMode', '02', ' '
	FROM AsActivity
	JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
		AND AsTransaction.TransactionName = 'DefineCoverageReinsuranceDetails'
	JOIN AsActivityMultiValueField ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID
		AND AsActivityMultiValueField.FieldName = 'InsuredRiskCession'
	WHERE AsActivity.ActivityGUID NOT IN (
		SELECT AsActivityMultiValueField.ActivityGUID 
		FROM AsActivityMultiValueField
        JOIN AsActivity ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID
        JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
            AND AsTransaction.TransactionName = 'DefineCoverageReinsuranceDetails'
		WHERE AsActivityMultiValueField.FieldName = 'ReinsuranceFacSplitCessionMode'        
	    );

    INSERT INTO AsActivityMultiValueField (ActivityGUID, FieldIndex, FieldName, FieldTypeCode, FloatValue)
    SELECT AsActivity.ActivityGUID, AsActivityMultiValueField.FieldIndex, 'ReinsuranceForcedRateAdjustmentFactor', '04', 1
    FROM AsActivity
    JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
        AND AsTransaction.TransactionName = 'DefineCoverageReinsuranceDetails'
    JOIN AsActivityMultiValueField ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID
        AND AsActivityMultiValueField.FieldName = 'InsuredRiskCession'
    WHERE AsActivity.ActivityGUID NOT IN (
        SELECT AsActivityMultiValueField.ActivityGUID 
        FROM AsActivityMultiValueField
        JOIN AsActivity ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID
        JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
            AND AsTransaction.TransactionName = 'DefineCoverageReinsuranceDetails'
        WHERE AsActivityMultiValueField.FieldName = 'ReinsuranceForcedRateAdjustmentFactor'        
        );

    INSERT INTO AsActivityMultiValueField (ActivityGUID, FieldIndex, FieldName, FieldTypeCode, FloatValue)
    SELECT AsActivity.ActivityGUID, AsActivityMultiValueField.FieldIndex, 'ReinsuranceFaceAmount', '04', 0
    FROM AsActivity
    JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
        AND AsTransaction.TransactionName = 'DefineCoverageReinsuranceDetails'
    JOIN AsActivityMultiValueField ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID
        AND AsActivityMultiValueField.FieldName = 'InsuredRiskCession'
    WHERE AsActivity.ActivityGUID NOT IN (
        SELECT AsActivityMultiValueField.ActivityGUID 
        FROM AsActivityMultiValueField
        JOIN AsActivity ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID
        JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
            AND AsTransaction.TransactionName = 'DefineCoverageReinsuranceDetails'
        WHERE AsActivityMultiValueField.FieldName = 'ReinsuranceFaceAmount'        
        );		
END;
/