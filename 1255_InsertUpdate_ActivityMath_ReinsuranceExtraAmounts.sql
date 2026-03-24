DECLARE 
    VSQL1 VARCHAR2(32767);
    VSQL2 VARCHAR2(32767);
    VSQL3 VARCHAR2(32767);
    VSQL4 VARCHAR2(32767);
    VSQL5 VARCHAR2(32767);
    VSQL6 VARCHAR2(32767);
    VRESULT VARCHAR2(200);
    
BEGIN 
-- Insert ReinsuranceExtraPremiumPRDLog in AsActivityMath 
VSQL1:='
	INSERT INTO AsActivityMath (ActivityGUID, MathName, MathValue, SourceTypeCode)
	SELECT ActivityGUID, ''ReinsuranceExtraPremiumPRDLog'', ''0.00'', ''01''
	FROM (
		SELECT AsActivity.ActivityGUID
		FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''ReinsuranceInitiateRiskCession'',''ReinsuranceRenewRiskCession'',''ReinsuranceAdjustRiskCession'',''ReinsuranceStopRiskCession'',''ReinsuranceClaimCededRisk'',''ReinsuranceRestartRiskCession'')
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT ActivityGUID FROM AsActivityMath WHERE MathName = ''ReinsuranceExtraPremiumPRDLog''
		)
	)';
	
-- Insert ReinsuranceExtraPremiumTRDLog in AsActivityMath 
VSQL2:='
	INSERT INTO AsActivityMath (ActivityGUID, MathName, MathValue, SourceTypeCode)
	SELECT ActivityGUID, ''ReinsuranceExtraPremiumTRDLog'', ''0.00'', ''01''
	FROM (
		SELECT AsActivity.ActivityGUID
		FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''ReinsuranceInitiateRiskCession'',''ReinsuranceRenewRiskCession'',''ReinsuranceAdjustRiskCession'',''ReinsuranceStopRiskCession'',''ReinsuranceClaimCededRisk'',''ReinsuranceRestartRiskCession'')
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT ActivityGUID FROM AsActivityMath WHERE MathName = ''ReinsuranceExtraPremiumTRDLog''
		)
	)';
	
-- Insert ReinsuranceExtraPremiumAllowancePRDLog in AsActivityMath 
VSQL3:='
	INSERT INTO AsActivityMath (ActivityGUID, MathName, MathValue, SourceTypeCode)
	SELECT ActivityGUID, ''ReinsuranceExtraPremiumAllowancePRDLog'', ''0.00'', ''01''
	FROM (
		SELECT AsActivity.ActivityGUID
		FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''ReinsuranceInitiateRiskCession'',''ReinsuranceRenewRiskCession'',''ReinsuranceAdjustRiskCession'',''ReinsuranceStopRiskCession'',''ReinsuranceClaimCededRisk'',''ReinsuranceRestartRiskCession'')
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT ActivityGUID FROM AsActivityMath WHERE MathName = ''ReinsuranceExtraPremiumAllowancePRDLog''
		)
	)';
	
-- Insert ReinsuranceExtraPremiumAllowanceTRDLog in AsActivityMath 
VSQL4:='
	INSERT INTO AsActivityMath (ActivityGUID, MathName, MathValue, SourceTypeCode)
	SELECT ActivityGUID, ''ReinsuranceExtraPremiumAllowanceTRDLog'', ''0.00'', ''01''
	FROM (
		SELECT AsActivity.ActivityGUID
		FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''ReinsuranceInitiateRiskCession'',''ReinsuranceRenewRiskCession'',''ReinsuranceAdjustRiskCession'',''ReinsuranceStopRiskCession'',''ReinsuranceClaimCededRisk'',''ReinsuranceRestartRiskCession'')
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT ActivityGUID FROM AsActivityMath WHERE MathName = ''ReinsuranceExtraPremiumAllowanceTRDLog''
		)
	)';
	
-- Rename ReinsuranceExtraPremiumLog to ReinsuranceExtraPremiumPRPLog in AsActivityMath 
VSQL5:='
    UPDATE AsActivityMath SET MathName = ''ReinsuranceExtraPremiumPRPLog''
    WHERE MathName = ''ReinsuranceExtraPremiumLog'' 
        AND ActivityGUID NOT IN (SELECT ActivityGUID FROM AsActivityMath WHERE  MathName = ''ReinsuranceExtraPremiumLog'')
    ';
    
-- Rename ReinsuranceExtraPremiumAllowanceLog to ReinsuranceExtraPremiumAllowancePRPLog in AsActivityMath 
VSQL6:='
    UPDATE AsActivityMath SET MathName = ''ReinsuranceExtraPremiumAllowancePRPLog''
    WHERE MathName = ''ReinsuranceExtraPremiumAllowanceLog''
         AND ActivityGUID NOT IN (SELECT ActivityGUID FROM AsActivityMath WHERE  MathName = ''ReinsuranceExtraPremiumAllowanceLog'')
    ';
    
VRESULT := NULL;

EXECUTESQL ( VSQL1, VRESULT );
EXECUTESQL ( VSQL2, VRESULT );
EXECUTESQL ( VSQL3, VRESULT );
EXECUTESQL ( VSQL4, VRESULT );
EXECUTESQL ( VSQL5, VRESULT );
EXECUTESQL ( VSQL6, VRESULT );

END;
/