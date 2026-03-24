DECLARE 
    VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);
	VSQL3 VARCHAR2(32767);
	VSQL4 VARCHAR2(32767);
	VSQL5 VARCHAR2(32767);
    VRESULT VARCHAR2(200);
BEGIN 
	-- Insert BenefitPaymentsDaysUsed in AsSegmentField
	VSQL1:='
		INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, IntValue)
		SELECT SegmentGUID, ''BenefitPaymentsDaysUsed'', ''03'', 0
		FROM AsSegment
		WHERE AsSegment.SegmentGUID NOT IN 
			(
				SELECT AsSegmentField.SegmentGUID
				FROM AsSegment
				JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsSegment.SegmentGUID
				WHERE AsSegmentField.FieldName = ''BenefitPaymentsDaysUsed''
			)';
	-- Insert ClaimPaymentsRemainingDays in AsSegmentField
	VSQL2:='
		INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, IntValue)
		SELECT SegmentGUID, ''ClaimPaymentsRemainingDays'', ''03'', 0
		FROM AsSegment
		WHERE AsSegment.SegmentGUID NOT IN 
			(
				SELECT AsSegmentField.SegmentGUID
				FROM AsSegment
				JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsSegment.SegmentGUID
				WHERE AsSegmentField.FieldName = ''ClaimPaymentsRemainingDays''
			)';			

	-- Insert ClaimBenefitPaymentAmount in AsSegmentField
	VSQL3:='
		INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, FloatValue, CurrencyCode)
		SELECT SegmentGUID, ''ClaimBenefitPaymentAmount'', ''04'', 0,''CAD''
		FROM AsSegment
		WHERE AsSegment.SegmentGUID NOT IN 
			(
				SELECT AsSegmentField.SegmentGUID
				FROM AsSegment
				JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsSegment.SegmentGUID
				WHERE AsSegmentField.FieldName = ''ClaimBenefitPaymentAmount''
			)';				

	-- Insert ClaimBenefitPaymentFrequency in AsSegmentField
	VSQL4:='
		INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
		SELECT SegmentGUID, ''ClaimBenefitPaymentFrequency'', ''02'', ''00'', 1, ''AsCodeComboNALD''
		FROM AsSegment
		WHERE AsSegment.SegmentGUID NOT IN 
			(
				SELECT AsSegmentField.SegmentGUID
				FROM AsSegment
				JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsSegment.SegmentGUID
				WHERE AsSegmentField.FieldName = ''ClaimBenefitPaymentFrequency''
			)';			

	-- Insert BenefitPaymentsCumulativeAmount in AsSegmentField
	VSQL5:='
		INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, FloatValue, CurrencyCode)
		SELECT SegmentGUID, ''BenefitPaymentsCumulativeAmount'', ''04'', 0, ''CAD''
		FROM AsSegment
		WHERE AsSegment.SegmentGUID NOT IN 
			(
				SELECT AsSegmentField.SegmentGUID
				FROM AsSegment
				JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsSegment.SegmentGUID
				WHERE AsSegmentField.FieldName = ''BenefitPaymentsCumulativeAmount''
			)';			
	VRESULT := NULL;

    EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );
	EXECUTESQL ( VSQL3, VRESULT );
	EXECUTESQL ( VSQL4, VRESULT );
	EXECUTESQL ( VSQL5, VRESULT );
END;
/