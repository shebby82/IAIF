DECLARE
    v_existing_rows		NUMBER := 0;
    v_affected_rows		NUMBER := 0;
    v_operation_type	VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'Reconciliation-GetSuspense';
    v_application_name VARCHAR2(50) := 'Modernia';
    v_version_number NUMBER := 4;
    v_currentuser VARCHAR(50) := 'ServiceLayer_IA';

    v_query_value CLOB := 
		'WITH PoliciesInformation AS (
    SELECT 
        AsProduct.ProductName,
        AsPlan.PlanName,
        AsPolicy.PolicyGUID,
        AsPolicy.PolicyNumber,
        SystemDesc.TranslationValue AS SystemCode,
        AsPolicy.StatusCode AS PolicyStatus
    FROM AsPolicy
    JOIN (
        SELECT 
            AsPolicy.PolicyNumber, 
            MIN(AsPolicy.SystemCode) AS SystemCode
        FROM AsPolicy
        WHERE (''[Policynumber]'' IS NULL OR INSTR(''[Policynumber]'', AsPolicy.PolicyNumber) > 0 )
        GROUP BY AsPolicy.PolicyNumber
    ) t ON t.PolicyNumber = AsPolicy.PolicyNumber
        AND t.SystemCode = AsPolicy.SystemCode
    JOIN AsPlan ON AsPlan.PlanGUID = AsPolicy.PlanGUID
    JOIN AsProduct ON AsProduct.ProductGUID = AsPlan.ProductGUID
    JOIN AsCode SystemCode ON SystemCode.CodeValue = AsPolicy.SystemCode
        AND SystemCode.CodeName = ''AsCodeSystem''
    JOIN AsTranslation SystemDesc ON SystemDesc.TranslationKey = SystemCode.ShortDescription
        AND SystemDesc.Locale = ''fr-CA''
)
,GeneratingTransactions AS (
    SELECT DISTINCT AsTransaction.TransactionGUID, AsTransaction.TransactionName 
    FROM AsTransaction
    JOIN AsBusinessRules ON AsBusinessRules.TransactionGUID = AsTransaction.TransactionGUID
        AND AsBusinessRules.RuleName = ''GenerateSuspense''
)
, MaintainingTransactions AS (
    SELECT DISTINCT AsTransaction.TransactionGUID, AsTransaction.TransactionName 
    FROM AsTransaction
    JOIN AsBusinessRules ON AsBusinessRules.TransactionGUID = AsTransaction.TransactionGUID
        AND AsBusinessRules.RuleName = ''MaintainSuspense''
)
, GeneratingActivities AS (
    SELECT PoliciesInformation.PolicyGUID, AsActivity.ActivityGUID, GeneratingTransactions.TransactionName, AsActivity.XMLData, AsActivity.ActivityGMT, AsActivity.TypeCode
    FROM AsActivity
    JOIN GeneratingTransactions ON GeneratingTransactions.TransactionGUID = AsActivity.TransactionGUID
    JOIN PoliciesInformation ON PoliciesInformation.PolicyGUID = AsActivity.PolicyGUID
    WHERE AsActivity.StatusCode = ''01''
		AND AsActivity.ActivityGMT >= TO_TIMESTAMP(''[StartDate]'', ''YYYY-MM-DD HH24:MI:SS.FF3'')
		AND AsActivity.ActivityGMT <= TO_TIMESTAMP(''[EndDate]'', ''YYYY-MM-DD HH24:MI:SS.FF3'') 
)
, MaintainingActivities AS (
    SELECT PoliciesInformation.PolicyGUID, AsActivity.ActivityGUID, MaintainingTransactions.TransactionName, AsActivity.XMLData, AsActivity.ActivityGMT, AsActivity.TypeCode
    FROM AsActivity
    JOIN MaintainingTransactions ON MaintainingTransactions.TransactionGUID = AsActivity.TransactionGUID
    JOIN PoliciesInformation ON PoliciesInformation.PolicyGUID = AsActivity.PolicyGUID
    WHERE AsActivity.StatusCode = ''01''
		AND AsActivity.ActivityGMT >= TO_TIMESTAMP(''[StartDate]'', ''YYYY-MM-DD HH24:MI:SS.FF3'')
		AND AsActivity.ActivityGMT <= TO_TIMESTAMP(''[EndDate]'', ''YYYY-MM-DD HH24:MI:SS.FF3'') 
)
, GeneratingActivitiesSuspensesFwd AS (
    SELECT
        t.PolicyGUID, 
        t.ActivityGUID,
        t.ActivityGMT,
        t.TransactionName,
        t.SuspenseGUID,
        ''0'' AS AttachedAmount,
        ''15'' AS StatusCode
    FROM (

        SELECT 
            GeneratingActivities.PolicyGUID
            , GeneratingActivities.ActivityGUID
            , GeneratingActivities.ActivityGMT
            , GeneratingActivities.TransactionName
            , SUBSTR(NewSuspense.NewSuspenseGUID,15,36) AS SuspenseGUID
        FROM GeneratingActivities
        JOIN XMLTABLE(''/Activity/Inserts/AsSuspense''
            PASSING XMLPARSE(CONTENT GeneratingActivities.XMLData)
            COLUMNS NewSuspenseGUID VARCHAR(100) PATH ''./@KEY''
            ) NewSuspense
            ON 1=1
        WHERE GeneratingActivities.TypeCode IN (''01'',''04'')    
    ) t
)
, GeneratingActivitiesSuspensesBkw AS (
    SELECT
        t.PolicyGUID, 
        t.ActivityGUID,
        t.ActivityGMT,
        t.TransactionName,
        t.SuspenseGUID,
        ''0'' AS AttachedAmount,
        ''12'' AS StatusCode
    FROM (
        SELECT 
            GeneratingActivities.PolicyGUID
            , GeneratingActivities.ActivityGUID
            , GeneratingActivities.ActivityGMT
            , GeneratingActivities.TransactionName
            , SUBSTR(NewSuspense.NewSuspenseGUID,17,36) AS SuspenseGUID
        FROM GeneratingActivities
        JOIN XMLTABLE(''/Activity/ReversalChanges/AsSuspense''
            PASSING XMLPARSE(CONTENT GeneratingActivities.XMLData)
            COLUMNS NewSuspenseGUID VARCHAR(100) PATH ''./@WHERE''
            ) NewSuspense
            ON 1=1
        WHERE GeneratingActivities.TypeCode IN (''02'',''03'')    
    ) t
)
, MaintainingActivitiesSuspenses AS (
    SELECT 
        t.PolicyGUID,
        t.ActivityGUID, 
        t.ActivityGMT,
        t.TransactionName,
        t.SuspenseGUID,
        TO_CHAR(t.AttachedAmount) AS AttachedAmount,
        NVL(t.StatusCode,''15'') AS StatusCode
    FROM (
        SELECT *
        FROM (
            SELECT 
                MaintainingActivities.PolicyGUID
                , MaintainingActivities.ActivityGUID
                , MaintainingActivities.ActivityGMT
                , MaintainingActivities.TransactionName
                , SUBSTR(UpdatedSuspense.UpdatedSuspenseGUID,17,36) AS SuspenseGUID
                , UpdatedSuspense.UpdatedSuspenseFieldName AS FieldName
                , UpdatedSuspense.UpdatedSuspenseFieldValue AS FieldValue
            FROM MaintainingActivities
            JOIN XMLTABLE(''/Activity/Changes/AsSuspense''
                PASSING XMLPARSE(CONTENT MaintainingActivities.XMLData)
                COLUMNS 
                    UpdatedSuspenseGUID VARCHAR(100) PATH ''./@WHERE''
                  , UpdatedSuspenseFieldName VARCHAR(200) PATH ''./@FIELD''
                  , UpdatedSuspenseFieldValue VARCHAR(100) PATH ''./New''
                ) UpdatedSuspense
                ON 1=1
        ) 
        PIVOT
        (
            MAX(FieldValue)
            FOR FieldName IN 
            (
                ''AttachedAmount'' AS AttachedAmount, 
                ''StatusCode'' AS StatusCode 
            )
        )
    ) t 
)
, ActivitiesSuspenses AS (
    SELECT tt.PolicyGUID, tt.ActivityGUID, tt.ActivityGMT, tt.TransactionName, tt.SuspenseGUID, tt.AttachedAmount, tt.StatusCode
    FROM (
        SELECT t.PolicyGUID, t.ActivityGUID, t.ActivityGMT, t.TransactionName, t.SuspenseGUID, t.AttachedAmount, t.StatusCode
            , ROW_NUMBER() OVER (PARTITION BY t.SuspenseGUID ORDER BY t.ActivityGMT DESC) AS RowNumber
        FROM (
            SELECT * 
            FROM GeneratingActivitiesSuspensesFwd 
            UNION
            SELECT * 
            FROM GeneratingActivitiesSuspensesBkw 
            UNION
            SELECT *
            FROM MaintainingActivitiesSuspenses
        ) t    
    ) tt
    WHERE tt.RowNumber = 1
)
, SuspenseInformation AS (
    SELECT 
        ActivitiesSuspenses.SuspenseGUID, 
        AsSuspense.SuspenseNumber,
        AsSuspense.CurrencyCode,
        AsSuspense.TypeCode AS SuspenseType,
        AsSuspense.StatusCode AS SuspenseStatus,
        AsSuspense.Amount,
        ActivitiesSuspenses.AttachedAmount,
        AsSuspense.Amount - ActivitiesSuspenses.AttachedAmount AS AvailableAmount,
        AsSuspense.EffectiveDate,
        AsSuspense.EffectiveFromDate,
        AsSuspense.EffectiveToDate,
        AsSuspense.UpdatedGMT
    FROM ActivitiesSuspenses
    JOIN AsSuspense ON AsSuspense.SuspenseGUID = ActivitiesSuspenses.SuspenseGUID
)
SELECT 
    SuspenseInformation.SuspenseGUID,
    ActivitiesSuspenses.ActivityGUID,
    PoliciesInformation.ProductName,
    PoliciesInformation.PlanName,
    PoliciesInformation.PolicyNumber,
    PoliciesInformation.SystemCode,
    PoliciesInformation.PolicyStatus,
    SuspenseInformation.SuspenseNumber,
    SuspenseInformation.CurrencyCode,
    SuspenseInformation.SuspenseType,
    SuspenseInformation.SuspenseStatus,
    SuspenseInformation.Amount,
    SuspenseInformation.AttachedAmount,
    SuspenseInformation.AvailableAmount,
	TO_CHAR(SuspenseInformation.EffectiveDate, ''YYYY-MM-DD'') AS EffectiveDate,
	TO_CHAR(SuspenseInformation.EffectiveFromDate, ''YYYY-MM-DD'') AS EffectiveFromDate,
	TO_CHAR(SuspenseInformation.EffectiveToDate, ''YYYY-MM-DD'') AS EffectiveToDate,
    TO_CHAR(ActivitiesSuspenses.ActivityGMT, ''YYYY-MM-DD HH24:MI:SS.FF3'') AS ActivityGMT
FROM ActivitiesSuspenses
JOIN PoliciesInformation ON PoliciesInformation.PolicyGUID = ActivitiesSuspenses.PolicyGUID
JOIN SuspenseInformation ON SuspenseInformation.SuspenseGUID = ActivitiesSuspenses.SuspenseGUID';

BEGIN
    -- Check if a row with the same QueryName, ApplicationName and VersionNumber already exists
    SELECT COUNT(*)
    INTO   v_existing_rows
    FROM   ASRESTSERVICEQUERY
    WHERE  QUERYNAME       = v_query_name
      AND  APPLICATIONNAME = v_application_name
      AND  VERSIONNUMBER   = v_version_number;

    -- Perform INSERT or UPDATE based on existence
    IF v_existing_rows > 0 THEN
        -- Update existing row
        UPDATE ASRESTSERVICEQUERY
        SET    QUERYVALUE = v_query_value
        WHERE  QUERYNAME       = v_query_name
          AND  APPLICATIONNAME = v_application_name
          AND  VERSIONNUMBER   = v_version_number;

        v_operation_type := 'updated';
    ELSE
        -- Insert new row
        INSERT INTO AsRestServiceQuery (RestServiceQueryGUID, QueryName, VersionNumber, QueryValue, ApplicationName, SystemIndicator, CreatedGMT, CreatedUser)
        VALUES (NEWID(), v_query_name, v_version_number, v_query_value, v_application_name, 'N', current_date, v_currentuser );

        v_operation_type := 'inserted';
    END IF;
    
    v_affected_rows := SQL%ROWCOUNT;

    -- Output the operation type and affected rows
    DBMS_OUTPUT.PUT_LINE(v_affected_rows || ' row(s) ' || v_operation_type || '.' );
END;
/