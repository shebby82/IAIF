BEGIN
  INSERT /*+ parallel(4) */
  INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)

  WITH act_base AS (
    SELECT
      ACT.ActivityGUID,
      ACT.TransactionGUID,
      AF_INSURED.TextValue              AS InsuredRoleGUID,          
      AF_SEGMENT.TextValue              AS ReinsuranceSegmentGUID,
      SEG_INS_BASIS.TextValue           AS InsuranceBasis,
      SEG_COVERAGE.TextValue || '-RC1'  AS CoverageIdentifierDefault
    FROM AsActivity ACT
    JOIN AsActivityField AF_SEGMENT ON AF_SEGMENT.ActivityGUID = ACT.ActivityGUID
		  AND AF_SEGMENT.FieldName    = 'ReinsuranceSegmentGUID'
    LEFT JOIN AsActivityField AF_INSURED ON AF_INSURED.ActivityGUID = ACT.ActivityGUID
		  AND AF_INSURED.FieldName    = 'InsuredRoleGUID'
    JOIN AsTransaction TXN ON TXN.TransactionGUID = ACT.TransactionGUID
		  AND TXN.TransactionName = 'ReinsuranceInitiateRiskCession'
    JOIN AsSegmentField SEG_INS_BASIS ON SEG_INS_BASIS.SegmentGUID = AF_SEGMENT.TextValue
		  AND SEG_INS_BASIS.FieldName   = 'InsuranceBasis'
    JOIN AsSegmentField SEG_COVERAGE ON SEG_COVERAGE.SegmentGUID = AF_SEGMENT.TextValue
		  AND SEG_COVERAGE.FieldName   = 'CoverageIdentifier'
    WHERE ACT.StatusCode = '01'
  ),

  seg_rci_agg AS (
    SELECT
      ROLE_REIN.SegmentGUID,
      LISTAGG(DISTINCT RF_RCI.TextValue, '') WITHIN GROUP (ORDER BY RF_RCI.TextValue)
        AS SegmentRCI
    FROM AsRole ROLE_REIN
    JOIN AsRoleField RF_RCI ON RF_RCI.RoleGUID  = ROLE_REIN.RoleGUID
		  AND RF_RCI.FieldName = 'RiskCessionIdentifier'
    WHERE ROLE_REIN.RoleCode   = '97'
		  AND ROLE_REIN.StatusCode = '01'
    GROUP BY ROLE_REIN.SegmentGUID
  ),

  insured_rci_agg AS (
    SELECT
      RF_INSURED.TextValue AS Insured,
      LISTAGG(DISTINCT RF_RCI.TextValue, '') WITHIN GROUP (ORDER BY RF_RCI.TextValue) AS InsuredRCI
    FROM AsRole ROLE_REIN
    JOIN AsRoleField RF_INSURED ON RF_INSURED.RoleGUID  = ROLE_REIN.RoleGUID
		  AND RF_INSURED.FieldName = 'Insured'
    JOIN AsRoleField RF_RCI ON RF_RCI.RoleGUID  = ROLE_REIN.RoleGUID
		  AND RF_RCI.FieldName = 'RiskCessionIdentifier'
    WHERE ROLE_REIN.RoleCode   = '97'
		  AND ROLE_REIN.StatusCode = '01'
    GROUP BY RF_INSURED.TextValue
  ),

  rci_values AS (
    SELECT
      B.ActivityGUID,
      B.TransactionGUID,
      CASE
        WHEN B.InsuranceBasis = 'JLTD' THEN
          NVL(SR.SegmentRCI, B.CoverageIdentifierDefault)
        ELSE
          NVL(IR.InsuredRCI, B.CoverageIdentifierDefault)
      END AS RiskCessionIdentifierValue
    FROM act_base B
    LEFT JOIN seg_rci_agg    SR ON SR.SegmentGUID = B.ReinsuranceSegmentGUID
    LEFT JOIN insured_rci_agg IR ON IR.Insured    = B.InsuredRoleGUID
  )

  SELECT RV.ActivityGUID, 'RiskCessionIdentifier', '02', RV.RiskCessionIdentifierValue
  FROM rci_values RV
  WHERE NOT EXISTS (
    SELECT 1
    FROM AsActivity ACT_CHECK
    JOIN AsActivityField AF_RCI ON AF_RCI.ActivityGUID = ACT_CHECK.ActivityGUID
		  AND AF_RCI.FieldName    = 'RiskCessionIdentifier'
    JOIN AsTransaction TXN_CHECK ON TXN_CHECK.TransactionGUID = ACT_CHECK.TransactionGUID
		  AND TXN_CHECK.TransactionName = 'ReinsuranceInitiateRiskCession'
    WHERE ACT_CHECK.ActivityGUID = RV.ActivityGUID
		  AND ACT_CHECK.StatusCode   = '01'
  );
END;
/