DECLARE
  VSQL1 VARCHAR2(32767);
  VRESULT VARCHAR2(200);
BEGIN

    -- Insert the EndOfPeriodGINextExerciseDate WHERE StartOfPeriodGINextExerciseDate IS NOT NULL
	VSQL1 := '
		INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, DateValue)
		SELECT StartOfPeriodGINextExerciseDate.SegmentGUID, ''EndOfPeriodGINextExerciseDate'', ''01'', StartOfPeriodGINextExerciseDate.DateValue + 31
		FROM AsSegmentField StartOfPeriodGINextExerciseDate
		WHERE StartOfPeriodGINextExerciseDate.FieldName = ''StartOfPeriodGINextExerciseDate''
			AND StartOfPeriodGINextExerciseDate.DateValue IS NOT NULL
			AND StartOfPeriodGINextExerciseDate.SegmentGUID NOT IN (
                SELECT SegmentGUID
                FROM AsSegmentField
                WHERE FieldName = ''EndOfPeriodGINextExerciseDate''
                )
		';

	VRESULT := NULL;
	EXECUTESQL(VSQL1, VRESULT);

END;
/