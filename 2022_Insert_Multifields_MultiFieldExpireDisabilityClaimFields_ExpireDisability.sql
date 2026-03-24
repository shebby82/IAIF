DECLARE
    
    CURSOR ActivityInfo_Cursor IS 
    
    WITH 
    Activity_Info_Index AS (
		SELECT DISTINCT AsActivityMultiValueField.activityguid, count(1) as fieldindex 
		FROM AsActivityMultiValueField
		JOIN AsActivity ON AsActivity.activityguid = AsActivityMultiValueField.activityguid
		JOIN AsTransaction ON AsTransaction.transactionguid = AsActivity.transactionguid
		WHERE AsTransaction.transactionname = ('ExpireDisabilityClaim') 
				AND AsActivityMultiValueField.fieldname = 'ClaimEligibility'
		GROUP BY AsActivityMultiValueField.activityguid, AsActivityMultiValueField.fieldname, AsTransaction.transactionname
    )
    
    
	SELECT activityguid, fieldindex FROM Activity_Info_Index;
	
     -- Variables to hold cursor data
     v_activityguid AsActivity.ActivityGuid%TYPE;
	 v_fieldindex number(10);
	 
	 -- Variables to validate the existence of the records in the AsActivityMultiValueField table before doing an insert
	 v_ExpireDisability number;
BEGIN
   
    -- Open the cursor and process each record
    OPEN ActivityInfo_Cursor;
    
    LOOP
        -- Fetch data into the variables
        FETCH ActivityInfo_Cursor INTO  v_activityguid, v_fieldindex;
        
        -- Exit when no more rows to fetch
        EXIT WHEN ActivityInfo_Cursor%NOTFOUND;
        
		FOR i IN 0..(v_fieldindex - 1) LOOP
			
			SELECT count(1) into v_ExpireDisability FROM AsActivityMultivalueField 
			WHERE FieldName = 'ExpireDisability' AND FieldIndex = i AND ActivityGuid = v_activityguid;
			-- Check if the record ExpireDisability exists
			IF v_ExpireDisability = 0 THEN		
				-- Insert the fetched data into the AsActivityMultiValueField table	
				INSERT INTO ASACTIVITYMULTIVALUEFIELD (ActivityGuid, FieldName, FieldIndex, FieldTypeCode, TextValue, OptionTextFlag, OptionText, GroupName)
					VALUES(v_activityguid, 'ExpireDisability', i, '02', '01','1','AsCodeYesNo.YesSD','ExpireDisabilityClaimCoverages');
			END IF;
			
		END LOOP;
        
    
    END LOOP;
    
    -- Close the cursor
    CLOSE ActivityInfo_Cursor;
END;
/