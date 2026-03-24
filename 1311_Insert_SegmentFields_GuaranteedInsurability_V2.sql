DECLARE
  VSQL1 VARCHAR2(32767);
  VSQL2 VARCHAR2(32767);
  VRESULT VARCHAR2(200);
BEGIN

    
	-- Insert SegmentField GuaranteedInsurabilityExerciseCount   
	  VSQL1 := '
		INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode,IntValue)
		SELECT SegmentGUID, ''GuaranteedInsurabilityExerciseCount'', ''03'', 0
		FROM AsSegment
		WHERE SegmentGUID NOT IN (
		  SELECT SegmentGUID
		  FROM AsSegmentField
		  WHERE FieldName = ''GuaranteedInsurabilityExerciseCount''
		)'; 


	  -- Replace GuaranteedInsurabilityBenefitNextExerciseDate for StartOfPeriodGINextExerciseDate 
	  VSQL2 := '
		UPDATE AsSegmentField SET FieldName = ''StartOfPeriodGINextExerciseDate''
		WHERE FieldName = ''GuaranteedInsurabilityBenefitNextExerciseDate''
		  AND SegmentGUID NOT IN (
			SELECT SegmentGUID
			FROM AsSegmentField
			WHERE FieldName = ''StartOfPeriodGINextExerciseDate''
		  )';
	  
  VRESULT := NULL;
  EXECUTESQL(VSQL1, VRESULT);
  EXECUTESQL(VSQL2, VRESULT);
END;
/