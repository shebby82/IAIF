DECLARE
	VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);
	VSQL3 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN
-- Insert AsActivityMultiValueField ReinsuranceRetainedAmountCI, ReinsuranceRetainedAmountLI, ReinsuranceRetainedAmountLS in AsActivityMultiValueField of DefineCoverageReinsuranceDetails
VSQL1:= '
	INSERT INTO AsActivityMultiValueField (ActivityGUID, FieldName, FieldIndex, FieldTypeCode, FloatValue, CurrencyCode)
	SELECT AsActivityMultiValueField.ActivityGUID , ''ReinsuranceRetainedAmountCI'', AsActivityMultiValueField.FieldIndex, ''04'', 0, ''CAD''
	FROM AsActivity
	JOIN AsActivityMultiValueField ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID 
		AND AsActivityMultiValueField.FieldName = ''Insured''
	JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
		AND TransactionName = ''DefineCoverageReinsuranceDetails''
	WHERE AsActivity.ActivityGUID NOT IN 
			(
				SELECT AsActivity.ActivityGUID
				FROM AsActivity
				JOIN AsActivityMultiValueField ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID 
					AND AsActivityMultiValueField.FieldName = ''ReinsuranceRetainedAmountCI''
				JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
					AND TransactionName = ''DefineCoverageReinsuranceDetails''
			)
	';
	
VSQL2:= '
	INSERT INTO AsActivityMultiValueField (ActivityGUID, FieldName, FieldIndex, FieldTypeCode, FloatValue, CurrencyCode)
	SELECT AsActivityMultiValueField.ActivityGUID , ''ReinsuranceRetainedAmountLI'', AsActivityMultiValueField.FieldIndex, ''04'', 0, ''CAD''
	FROM AsActivity
	JOIN AsActivityMultiValueField ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID 
		AND AsActivityMultiValueField.FieldName = ''Insured''
	JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
		AND TransactionName = ''DefineCoverageReinsuranceDetails''
	WHERE AsActivity.ActivityGUID NOT IN 
			(
				SELECT AsActivity.ActivityGUID
				FROM AsActivity
				JOIN AsActivityMultiValueField ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID 
					AND AsActivityMultiValueField.FieldName = ''ReinsuranceRetainedAmountLI''
				JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
					AND TransactionName = ''DefineCoverageReinsuranceDetails''
			)
	';
	
VSQL3:= '
	INSERT INTO AsActivityMultiValueField (ActivityGUID, FieldName, FieldIndex, FieldTypeCode, FloatValue, CurrencyCode)
	SELECT AsActivityMultiValueField.ActivityGUID , ''ReinsuranceRetainedAmountLS'', AsActivityMultiValueField.FieldIndex, ''04'', 0, ''CAD''
	FROM AsActivity
	JOIN AsActivityMultiValueField ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID 
		AND AsActivityMultiValueField.FieldName = ''Insured''
	JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
		AND TransactionName = ''DefineCoverageReinsuranceDetails''
	WHERE AsActivity.ActivityGUID NOT IN 
			(
				SELECT AsActivity.ActivityGUID
				FROM AsActivity
				JOIN AsActivityMultiValueField ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID 
					AND AsActivityMultiValueField.FieldName = ''ReinsuranceRetainedAmountLS''
				JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
					AND TransactionName = ''DefineCoverageReinsuranceDetails''
			)
	';
	
    VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );
	EXECUTESQL ( VSQL3, VRESULT );

END;
/