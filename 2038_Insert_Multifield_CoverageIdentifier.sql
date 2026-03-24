BEGIN
    INSERT INTO ASACTIVITYMULTIVALUEFIELD (ActivityGuid, FieldName, FieldIndex, FieldTypeCode, TextValue)
        WITH  Activity_Info AS (
            SELECT
                AsSegmentField.TextValue AS CoverageIdentifier,
                ROW_NUMBER() OVER (
                    PARTITION BY AsPolicy.PolicyGUID 
                    ORDER BY AsSegmentField.TextValue
                )AS fieldindex,
                AsPolicy.PolicyGUID AS PolicyGUID,
                AsSegment.SegmentGUID AS SegmentGUID
            FROM AsPolicy
            JOIN AsSegment ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID
            JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsSegment.SegmentGUID 
            AND AsSegmentField.FieldName = 'CoverageIdentifier'
            )    
        SELECT AsActivity.ActivityGUID, 'CoverageIdentifier', fieldindex-1, '02', Activity_Info.CoverageIdentifier
        FROM AsActivity 
        JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
            AND AsTransaction.TransactionGUID = '8BC187AD-952F-41D3-81D3-35AEB35185EA'
        JOIN Activity_Info ON  Activity_Info.PolicyGUID = AsActivity.PolicyGUID
        WHERE AsActivity.ActivityGUID NOT IN (
		   SELECT AsActivityMultiValueField.ActivityGUID 
		   FROM AsActivityMultiValueField
           JOIN AsActivity ON AsActivityMultiValueField.ActivityGUID = AsActivity.ActivityGUID
           JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID 
               AND AsTransaction.TransactionGUID = '8BC187AD-952F-41D3-81D3-35AEB35185EA'
		   WHERE AsActivityMultiValueField.FieldName = 'CoverageIdentifier'
           );
END;
/