DECLARE 
  VSQL1 VARCHAR2(32767);
  VSQL2 VARCHAR2(32767);
  VSQL3 VARCHAR2(32767);
  VSQL4 VARCHAR2(32767);
  VSQL5 VARCHAR2(32767);
  VSQL6 VARCHAR2(32767);
  VSQL7 VARCHAR2(32767);
  VSQL8 VARCHAR2(32767);
  VSQL9 VARCHAR2(32767);
  VRESULT VARCHAR2(32767);

BEGIN 

  -- Insert RoleField ReinsuranceFaceAmountAtActivation on SegmentRole Reinsurer 
  VSQL1:='
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue, CurrencyCode)
    SELECT Reinsurer.RoleGUID, ''ReinsuranceFaceAmountAtActivation'', ''04'', AsSegmentField.FloatValue, AsSegmentField.CurrencyCode
    FROM AsRole Reinsurer
    JOIN AsSegmentField ON AsSegmentField.SegmentGUID = Reinsurer.SegmentGUID
		AND AsSegmentField.FieldName = ''ReinsuranceFaceAmountAtActivation''
    WHERE Reinsurer.RoleCode = ''97''
		AND Reinsurer.RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''ReinsuranceFaceAmountAtActivation''
			)
  ';

  -- Insert RoleField ReinsuranceProrataForCoverageLife on SegmentRole Reinsurer 
  VSQL2:='
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue)
    SELECT Reinsurer.RoleGUID, ''ReinsuranceProrataForCoverageLife'', ''04'', AsSegmentField.FloatValue
    FROM AsRole Reinsurer
    JOIN AsSegmentField ON AsSegmentField.SegmentGUID = Reinsurer.SegmentGUID
		AND AsSegmentField.FieldName = ''ReinsuranceProrataForCoverageLife''
    WHERE Reinsurer.RoleCode = ''97''
		AND Reinsurer.RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''ReinsuranceProrataForCoverageLife''
			)
  ';  

  -- Insert RoleField ReinsuranceExtraPremiumAmountPRD on SegmentRole Reinsurer 
  VSQL3:='
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue, CurrencyCode)
    SELECT Reinsurer.RoleGUID, ''ReinsuranceExtraPremiumAmountPRD'', ''04'', 0, ''CAD''
    FROM AsRole Reinsurer
    WHERE Reinsurer.RoleCode = ''97''
		AND Reinsurer.RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''ReinsuranceExtraPremiumAmountPRD''
			)
  ';

   -- Insert RoleField ReinsuranceExtraPremiumRatingPRD on SegmentRole Reinsurer 
  VSQL4:='
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue)
    SELECT Reinsurer.RoleGUID, ''ReinsuranceExtraPremiumRatingPRD'', ''04'', 0
    FROM AsRole Reinsurer
    WHERE Reinsurer.RoleCode = ''97''
		AND Reinsurer.RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''ReinsuranceExtraPremiumRatingPRD''
			)
  '; 

   -- Insert RoleField ReinsuranceExtraPremiumAllowanceAmountPRD on SegmentRole Reinsurer 
  VSQL5:='
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue, CurrencyCode)
    SELECT Reinsurer.RoleGUID, ''ReinsuranceExtraPremiumAllowanceAmountPRD'', ''04'', 0, ''CAD''
    FROM AsRole Reinsurer
    WHERE Reinsurer.RoleCode = ''97''
		AND Reinsurer.RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''ReinsuranceExtraPremiumAllowanceAmountPRD''
			)
  ';

   -- Insert RoleField ReinsuranceExtraPremiumAmountTRD on SegmentRole Reinsurer 
  VSQL6:='
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue, CurrencyCode)
    SELECT Reinsurer.RoleGUID, ''ReinsuranceExtraPremiumAmountTRD'', ''04'', 0, ''CAD''
    FROM AsRole Reinsurer
    WHERE Reinsurer.RoleCode = ''97''
		AND Reinsurer.RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''ReinsuranceExtraPremiumAmountTRD''
			)
  ';

   -- Insert RoleField ReinsuranceExtraPremiumRatingTRD on SegmentRole Reinsurer 
  VSQL7:='
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue)
    SELECT Reinsurer.RoleGUID, ''ReinsuranceExtraPremiumRatingTRD'', ''04'', 0
    FROM AsRole Reinsurer
    WHERE Reinsurer.RoleCode = ''97''
		AND Reinsurer.RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''ReinsuranceExtraPremiumRatingTRD''
			)
  '; 

   -- Insert RoleField ReinsuranceExtraPremiumAllowanceAmountTRD on SegmentRole Reinsurer 
  VSQL8:='
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue, CurrencyCode)
    SELECT Reinsurer.RoleGUID, ''ReinsuranceExtraPremiumAllowanceAmountTRD'', ''04'', 0, ''CAD''
    FROM AsRole Reinsurer
    WHERE Reinsurer.RoleCode = ''97''
		AND Reinsurer.RoleGUID NOT IN (
			SELECT RoleGUID 
			FROM AsRoleField 
			WHERE FieldName = ''ReinsuranceExtraPremiumAllowanceAmountTRD''
			)
  ';

  VSQL9 := '
	DELETE FROM AsSegmentField
	WHERE FieldName IN (
		''ReinsuranceFaceAmountAtActivation'',''ReinsuranceProrataForCoverageLife''
		)
  ';

VRESULT := NULL;
EXECUTESQL ( VSQL1, VRESULT );
EXECUTESQL ( VSQL2, VRESULT );
EXECUTESQL ( VSQL3, VRESULT );
EXECUTESQL ( VSQL4, VRESULT );
EXECUTESQL ( VSQL5, VRESULT );
EXECUTESQL ( VSQL6, VRESULT );
EXECUTESQL ( VSQL7, VRESULT );
EXECUTESQL ( VSQL8, VRESULT );
EXECUTESQL ( VSQL9, VRESULT );

END;
/