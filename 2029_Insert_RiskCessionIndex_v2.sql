BEGIN
  INSERT /*+ parallel(4) */
  INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)

  WITH base AS (
    SELECT ACT.ActivityGUID,
           ACT.TransactionGUID,
           AF_INSURED.TextValue  AS InsuredRoleGUID,
           AF_SEGMENT.TextValue  AS ReinsuranceSegmentGUID
    FROM AsActivity ACT
    JOIN AsActivityField AF_INSURED ON AF_INSURED.ActivityGUID = ACT.ActivityGUID
		  AND AF_INSURED.FieldName    = 'InsuredRoleGUID'
    JOIN AsActivityField AF_SEGMENT ON AF_SEGMENT.ActivityGUID = ACT.ActivityGUID
		  AND AF_SEGMENT.FieldName    = 'ReinsuranceSegmentGUID'
    JOIN AsTransaction TXN ON TXN.TransactionGUID = ACT.TransactionGUID
		  AND TXN.TransactionName = 'ReinsuranceInitiateRiskCession'
    WHERE ACT.StatusCode = '01'
  ),

  seg_mode AS (
    SELECT ROLE_REIN.SegmentGUID,
           MAX(CASE WHEN RF_CESSION.FieldName = 'CessionMode'
                    THEN RF_CESSION.TextValue END) AS CessionMode
    FROM AsRole ROLE_REIN
    JOIN AsRoleField RF_CESSION ON RF_CESSION.RoleGUID = ROLE_REIN.RoleGUID
    WHERE ROLE_REIN.RoleCode   = '97'
		  AND ROLE_REIN.StatusCode = '01'
    GROUP BY ROLE_REIN.SegmentGUID
  ),

  insured_mode AS (
    SELECT RF_INSURED.TextValue AS Insured,
           MAX(CASE WHEN RF_CESSION.FieldName = 'CessionMode'
                    THEN RF_CESSION.TextValue END) AS CessionMode
    FROM AsRole ROLE_REIN
    JOIN AsRoleField RF_CESSION ON RF_CESSION.RoleGUID  = ROLE_REIN.RoleGUID
		  AND RF_CESSION.FieldName = 'CessionMode'
    JOIN AsRoleField RF_INSURED ON RF_INSURED.RoleGUID  = ROLE_REIN.RoleGUID
		  AND RF_INSURED.FieldName = 'Insured'
    WHERE ROLE_REIN.RoleCode   = '97'
		  AND ROLE_REIN.StatusCode = '01'
    GROUP BY RF_INSURED.TextValue
  ),

  risk AS (
    SELECT B.ActivityGUID,
           B.TransactionGUID,
           CASE
             WHEN B.InsuredRoleGUID = 'JLTD'
               THEN CASE WHEN SM.CessionMode = 'AUTO' THEN ' ' ELSE '0' END
             ELSE
               CASE WHEN IM.CessionMode = 'AUTO' THEN ' ' ELSE '0' END
           END AS RiskCessionIndex
    FROM base B
    LEFT JOIN seg_mode    SM ON SM.SegmentGUID = B.ReinsuranceSegmentGUID
    LEFT JOIN insured_mode IM ON IM.Insured    = B.InsuredRoleGUID
  )

  /*=================================================
    Insert new RiskCessionIndex where none exists yet
    Aliases:
      R         -> risk (computed values to insert)
      ACT      -> AsActivity (dup-check correlation)
      AF_RISK   -> AsActivityField (existing 'RiskCessionIndex')
  =================================================*/
  SELECT R.ActivityGUID, 'RiskCessionIndex', '02', R.RiskCessionIndex
  FROM risk R
  WHERE NOT EXISTS (
    SELECT 1
    FROM AsActivity ACT
    JOIN AsActivityField AF_RISK ON AF_RISK.ActivityGUID = ACT.ActivityGUID
      AND AF_RISK.FieldName    = 'RiskCessionIndex'
    WHERE ACT.ActivityGUID    = R.ActivityGUID
      AND ACT.TransactionGUID = R.TransactionGUID
      AND ACT.StatusCode      = '01'
  );
END;
/