DECLARE 
    VSQL1 VARCHAR2(32767);
    VSQL2 VARCHAR2(32767);
    VRESULT VARCHAR2(200);

CURSOR Policies IS

    SELECT  
        REGEXP_REPLACE(SYS_GUID(), '(.{8})(.{4})(.{4})(.{4})(.{12})', '\1-\2-\3-\4-\5') AS NewGUID,
        LOWER(REGEXP_REPLACE(SYS_GUID(), '(.{8})(.{4})(.{4})(.{4})(.{12})', '\1-\2-\3-\4-\5')) AS NewGUIDLowerCase,
        (SELECT TO_CHAR(SystemDate,'YYYY-MM-DD') FROM AsSystemDate WHERE CurrentIndicator = 'Y') AS CurrentSystemDate,
        AsPolicy.PolicyGUID AS PolicyGUID
    FROM AsPolicy
    JOIN AsPolicyField AppId ON AsPolicy.PolicyGUID = AppId.PolicyGUID
        AND AppId.FieldName = 'ApplicationIdentifier'
    JOIN AsActivity ON AsPolicy.PolicyGUID = AsActivity.PolicyGUID
        AND AsActivity.TypeCode IN ('01','04')
        AND AsActivity.StatusCode = '01'
        AND ADD_MONTHS(AsActivity.EffectiveDate,6) >= ( SELECT SystemDate FROM AsSystemDate WHERE CurrentIndicator = 'Y')
    JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
        AND AsTransaction.TransactionName = 'CancelApplication'
    WHERE AsPolicy.StatusCode = '04'
        AND AsPolicy.SystemCode = '02'
        AND AppId.textValue IN (
            SELECT DISTINCT AsPolicyField.textValue
            FROM AsPolicy
            JOIN AsPolicyField ON AsPolicy.PolicyGUID = AsPolicyField.PolicyGUID
                AND AsPolicyField.FieldName = 'ApplicationIdentifier'
            JOIN AsActivity ON AsPolicy.PolicyGUID = AsActivity.PolicyGUID
            JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
                AND AsTransaction.TransactionName IN ('ChangePolicyOwners', 'ChangeContingentPolicyOwners', 'ChangeServicingAgency', 'CompleteBeneficiariesChangeRequest', 'ChangePaymentTerms', 'UpdateBankingAuthorizationNumber', 'ChangeWithdrawalDay', 'TerminateCoverage', 'ReduceFaceAmount')
                AND AsActivity.TypeCode IN ('01','04')
                AND AsActivity.StatusCode = '01'
            WHERE AsPolicy.SystemCode = '01'
                AND AsPolicy.StatusCode = '01'
            )
    GROUP BY AsPolicy.PolicyGUID
    ;

BEGIN
	FOR item IN Policies
	LOOP
	
		VSQL1:= '
			INSERT INTO AsActivity
			(ActivityGUID, TransactionGUID, TypeCode, StatusCode, EffectiveDate, ClientNumber, PolicyGUID, ProcessingOrder, ErrorStatusCode, SuspenseStatusCode, EntryGMT, CreationGMT, OriginalActivityGUID)
			SELECT '''|| item.NewGUID ||''', ''40139CA3-470F-4B79-97EF-8FC52ED8DD84'', ''01'', ''02'', '''|| item.CurrentSystemDate ||''', ''oipauser'', '''|| item.PolicyGUID ||''', 25200, ''01'', ''01'',
			'''|| item.CurrentSystemDate ||''', '''|| item.CurrentSystemDate ||''', '''|| item.NewGUID ||''' FROM DUAL
			';

		VSQL2:=	'
			INSERT INTO AsActivityField
			(ActivityGUID, FieldName, FieldTypeCode, TextValue)
			SELECT '''|| item.NewGUID ||''', ''CorrelationID'', ''02'', '''|| item.NewGUIDLowerCase ||''' FROM DUAL
			';
			
	
	VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );

	END LOOP;
	
END;
/