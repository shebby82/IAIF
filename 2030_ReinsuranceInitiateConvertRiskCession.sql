BEGIN
    INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
    WITH ValuesList AS (
    SELECT
        AsActivity.ActivityGUID As ActivityGUID, CoverageIdentifier.TextValue || '-RC1'  As CoverageIdentifier,
        CASE
            WHEN InsuranceBasis.TextValue = 'JLTD' THEN (
                SELECT LISTAGG(Distinct(RiskCessionIdentifier.TextValue), '') WITHIN GROUP (ORDER BY RiskCessionIdentifier.TextValue)
                FROM AsActivityField ReSegGUID
                JOIN AsRole ON AsRole.SegmentGUID = ReinsuranceSegmentGUID.TextValue
                    AND AsRole.RoleCode = '97'
                    AND AsRole.StatusCode = '01'
                JOIN AsRoleField RiskCessionIdentifier ON RiskCessionIdentifier.RoleGUID = AsRole.RoleGUID
                    AND RiskCessionIdentifier.FieldName = 'RiskCessionIdentifier'
                    AND ReSegGUID.ActivityGUID = AsActivity.ActivityGUID     
            )
            ELSE (
                SELECT LISTAGG(Distinct(RiskCessionIdentifier.TextValue), '') WITHIN GROUP (ORDER BY RiskCessionIdentifier.TextValue)
                FROM AsActivityField InsuredRoleGUID
                JOIN AsRoleField Insured ON Insured.TextValue = InsuredRoleGUID.TextValue
                    AND Insured.FieldName = 'Insured'
                JOIN AsRole ON AsRole.RoleGUID = Insured.RoleGUID AND RoleCode = '97' AND StatusCode = '01'
                JOIN AsRoleField RiskCessionIdentifier ON RiskCessionIdentifier.RoleGUID = AsRole.RoleGUID AND RiskCessionIdentifier.FieldName= 'RiskCessionIdentifier'  
                WHERE InsuredRoleGUID.FieldName = 'InsuredRoleGUID'
                    AND InsuredRoleGUID.ActivityGUID = AsActivity.ActivityGUID
            )
        END AS RiskCessionIdentifierValue
    FROM AsActivityField ReinsuranceSegmentGUID
    JOIN AsActivity ON AsActivity.ActivityGUID = ReinsuranceSegmentGUID.ActivityGUID
        AND AsActivity.StatusCode = '01'
    JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
        AND AsTransaction.TransactionName = 'ReinsuranceInitiateConvertRiskCession'
    JOIN AsSegmentField InsuranceBasis ON InsuranceBasis.SegmentGUID = ReinsuranceSegmentGUID.TextValue
        AND InsuranceBasis.FieldName = 'InsuranceBasis'
    JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = ReinsuranceSegmentGUID.TextValue
        AND CoverageIdentifier.FieldName = 'CoverageIdentifier'     
    WHERE ReinsuranceSegmentGUID.FieldName = 'ReinsuranceSegmentGUID'
    )
    SELECT ValuesList.ActivityGUID, 'RiskCessionIdentifier', '02',
        CASE WHEN ValuesList.RiskCessionIdentifierValue IS NULL 
            THEN ValuesList.CoverageIdentifier
        ELSE ValuesList.RiskCessionIdentifierValue END
    FROM ValuesList
    WHERE ValuesList.ActivityGUID NOT IN (
        SELECT Distinct(AsActivity.ActivityGUID)
        FROM AsActivityField
        JOIN AsActivity ON AsActivity.ActivityGUID = AsActivityField.ActivityGUID
            AND AsActivity.StatusCode = '01'
        JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
            AND AsTransaction.TransactionName = 'ReinsuranceInitiateConvertRiskCession'
        WHERE FieldName = 'RiskCessionIdentifier'
        );
END;
/