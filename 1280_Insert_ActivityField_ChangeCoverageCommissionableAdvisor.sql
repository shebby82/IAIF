DECLARE 
    VSQL1 VARCHAR2(32767);
    VSQL2 VARCHAR2(32767);
    VSQL3 VARCHAR2(32767);
    VRESULT VARCHAR2(200);

BEGIN
	-- Insert ActivityField ServiceRequestID in ChangeCoverageCommisionableAdvisor, ChangeCoverageCommissionableAdvisorAtIssue, ChangeServicingAgency, ChangeServicingAgencyAtIssue
	VSQL1:= '
		INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode)
		SELECT ActivityGUID, ''ServiceRequestID'', ''02''
		FROM (
			SELECT AsActivity.ActivityGUID
			FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
				AND AsTransaction.TransactionName IN (''ChangeCoverageCommisionableAdvisor'', ''ChangeCoverageCommissionableAdvisorAtIssue'', ''ChangeServicingAgency'', ''ChangeServicingAgencyAtIssue'')
			WHERE AsActivity.ActivityGUID NOT IN (
				SELECT AsActivity.ActivityGUID
				FROM AsActivity
				JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
					AND AsTransaction.TransactionName IN (''ChangeCoverageCommisionableAdvisor'', ''ChangeCoverageCommissionableAdvisorAtIssue'', ''ChangeServicingAgency'', ''ChangeServicingAgencyAtIssue'')
				JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
					AND AsActivityField.FieldName = ''ServiceRequestID''
			)
		)';
    -- Insert ActivityField NewAdvisorCompensationAgreementCode in ChangeCoverageCommisionableAdvisor, ChangeCoverageCommissionableAdvisorAtIssue
	VSQL2:= '
		INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode)
		SELECT ActivityGUID, ''NewAdvisorCompensationAgreementCode'', ''02''
		FROM (
			SELECT AsActivity.ActivityGUID
			FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
				AND AsTransaction.TransactionName IN (''ChangeCoverageCommisionableAdvisor'', ''ChangeCoverageCommissionableAdvisorAtIssue'')
			WHERE AsActivity.ActivityGUID NOT IN (
				SELECT AsActivity.ActivityGUID
				FROM AsActivity
				JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
					AND AsTransaction.TransactionName IN (''ChangeCoverageCommisionableAdvisor'', ''ChangeCoverageCommissionableAdvisorAtIssue'')
				JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
					AND AsActivityField.FieldName = ''NewAdvisorCompensationAgreementCode''
			)
		)';
    -- Insert ActivityField FinancialCompensationWaived in ChangeCoverageCommisionableAdvisor, ChangeCoverageCommissionableAdvisorAtIssue
	VSQL3:= '
		INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
		SELECT ActivityGUID, ''FinancialCompensationWaived'', ''02'', ''CHECKED''
		FROM (
			SELECT AsActivity.ActivityGUID
			FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
				AND AsTransaction.TransactionName IN (''ChangeCoverageCommisionableAdvisor'', ''ChangeCoverageCommissionableAdvisorAtIssue'')
			WHERE AsActivity.ActivityGUID NOT IN (
				SELECT AsActivity.ActivityGUID
				FROM AsActivity
				JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
					AND AsTransaction.TransactionName IN (''ChangeCoverageCommisionableAdvisor'', ''ChangeCoverageCommissionableAdvisorAtIssue'')
				JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
					AND AsActivityField.FieldName = ''FinancialCompensationWaived''
			)
		)';
		
VRESULT := NULL;
    EXECUTESQL ( VSQL1, VRESULT );
    EXECUTESQL ( VSQL2, VRESULT );
    EXECUTESQL ( VSQL3, VRESULT );
END;
/