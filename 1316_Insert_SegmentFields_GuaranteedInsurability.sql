DECLARE
	VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);
	VRESULT VARCHAR2(200);
BEGIN
  
	-- Insert AsSegmentField StartOfPeriodGINextExerciseDate
	VSQL1 := '
		INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode)
		SELECT SegmentGUID, ''StartOfPeriodGINextExerciseDate'', ''01''
		FROM AsSegment
		WHERE SegmentGUID NOT IN (
			SELECT SegmentGUID
			FROM AsSegmentField
			WHERE FieldName = ''StartOfPeriodGINextExerciseDate''
			)';
	  
	-- Insert AsSegmentField EndOfPeriodGINextExerciseDate 
	VSQL2 := '
		INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode)
		SELECT SegmentGUID, ''EndOfPeriodGINextExerciseDate'', ''01''
		FROM AsSegment
		WHERE SegmentGUID NOT IN (
			SELECT SegmentGUID
			FROM AsSegmentField
			WHERE FieldName = ''EndOfPeriodGINextExerciseDate''
			)';
 
	VRESULT := NULL;
	EXECUTESQL(VSQL1, VRESULT);
	EXECUTESQL(VSQL2, VRESULT);
	
END;
/