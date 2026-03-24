DECLARE
  VSQL1 VARCHAR2(32767);
  VRESULT VARCHAR2(200);
BEGIN

    
	-- Insert ActivityField LoginClientGUID
	  VSQL1 := '
		INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode)
		SELECT AsActivity.ActivityGUID, ''LoginClientGUID'', ''02''
		FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
			AND AsTransaction.TransactionName = ''ChangeGIData''
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT AsActivity.ActivityGUID
			FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
				AND AsTransaction.TransactionName = ''ChangeGIData''
			JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
				AND AsActivityField.FieldName = ''LoginClientGUID''	
			)
		';  
 
  VRESULT := NULL;
  EXECUTESQL(VSQL1, VRESULT);
END;
/