BEGIN
    INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
    WITH ValuesList AS (
        SELECT
            AsActivity.ActivityGUID As ActivityGUID, CoverageIdentifier.TextValue || '-RC1' AS RiskCessionIdentifierValue
        FROM AsActivityField ReinsuranceSegmentGUID
        JOIN AsActivity ON AsActivity.ActivityGUID = ReinsuranceSegmentGUID.ActivityGUID
            AND AsActivity.StatusCode in ('02','09')
        JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
            AND AsTransaction.TransactionName = 'ReinsuranceInitiateRiskCession'
        JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = ReinsuranceSegmentGUID.TextValue
            AND CoverageIdentifier.FieldName = 'CoverageIdentifier'
        WHERE ReinsuranceSegmentGUID.FieldName = 'ReinsuranceSegmentGUID'
        )
    SELECT ValuesList.ActivityGUID, 'RiskCessionIdentifier', '02', ValuesList.RiskCessionIdentifierValue 
    FROM ValuesList
    WHERE ValuesList.ActivityGUID NOT IN (
        SELECT Distinct(AsActivity.ActivityGUID)
        FROM AsActivityField
        JOIN AsActivity ON AsActivity.ActivityGUID = AsActivityField.ActivityGUID
            AND AsActivity.StatusCode IN ('02','09')
        JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
            AND AsTransaction.TransactionName = 'ReinsuranceInitiateRiskCession'
        WHERE FieldName = 'RiskCessionIdentifier'
        );	
END;
/