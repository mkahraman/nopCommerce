﻿--upgrade scripts from nopCommerce 3.90 to 4.00

--new locale resources
declare @resources xml
--a resource will be deleted if its value is empty
set @resources='
<Language>
  <LocaleResource Name="Admin.System.SystemInfo.ServerVariables">
    <Value></Value>
  </LocaleResource>
  <LocaleResource Name="Admin.System.SystemInfo.ServerVariables.Hint">
    <Value></Value>
  </LocaleResource>
  <LocaleResource Name="Admin.System.SystemInfo.Headers">
    <Value>Headers</Value>
  </LocaleResource>
  <LocaleResource Name="Admin.System.SystemInfo.Headers.Hint">
    <Value>A list of headers.</Value>
  </LocaleResource>
  <LocaleResource Name="Admin.System.Warnings.MachineKey.NotSpecified">
    <Value></Value>
  </LocaleResource>
  <LocaleResource Name="Admin.System.Warnings.MachineKey.Specified">
    <Value></Value>
  </LocaleResource>
  <LocaleResource Name="Account.AssociatedExternalAuth.YourAccountWillBeLinkedTo.Remove">
    <Value></Value>
  </LocaleResource>
  <LocaleResource Name="Account.AssociatedExternalAuth.YourAccountWillBeLinkedTo">
    <Value></Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Configuration.Settings.CustomerUser.ExternalAuthenticationAutoRegisterEnabled">
    <Value></Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Configuration.Settings.CustomerUser.ExternalAuthenticationAutoRegisterEnabled.Hint">
    <Value></Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Configuration.Settings.CustomerUser.BlockTitle.ExternalAuthentication">
    <Value></Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Configuration.Plugins.OfficialFeed.Instructions">
    <Value><![CDATA[<p>Here you can find third-party extensions and themes which are developed by our community and partners.They are also available in our <a href="https://www.nopcommerce.com/marketplace.aspx?utm_source=admin-panel&utm_medium=official-plugins&utm_campaign=admin-panel" target="_blank">marketplace</a></p>]]></Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Configuration.Stores.Fields.SecureUrl.Hint">
    <Value>The secure URL of your store e.g. https://www.yourstore.com/ or http://sharedssl.yourstore.com/. Leave it empty if you want nopCommerce to detect secure URL automatically.</Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Configuration.Settings.GeneralCommon.Captcha.Instructions">
    <Value><![CDATA[<p>CAPTCHA is a program that can tell whether its user is a human or a computer. You''ve probably seen them — colorful images with distorted text at the bottom ofWeb registration forms. CAPTCHAs are used by many websites to prevent abuse from "bots" or automated programs usually written to generate spam. No computer programcan read distorted text as well as humans can, so bots cannot navigate sites protectedby CAPTCHAs. nopCommerce uses <a href="http://www.google.com/recaptcha" target="_blank">reCAPTCHA</a>.</p>]]></Value>
  </LocaleResource>
  <LocaleResource Name="Admin.ContentManagement.MessageTemplates.Description.Customer.EmailValidationMessage">
	  <Value>This message template is used when Configuration - Settings - Customer settings - "Registration method" dropdownlist is set to "Email validation". The customer receives a message to confirm an email address used when registering.</Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Configuration.Settings.Media.CategoryThumbPictureSize.Hint">
    <Value>The default size (pixels) for category thumbnail images.</Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Configuration.Settings.Media.ManufacturerThumbPictureSize.Hint">
    <Value>The default size (pixels) for manufacturer thumbnail images.</Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Customers.OnlineCustomers.Fields.IPAddress.Disabled">
    <Value>"Store IP addresses" setting is disabled</Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Configuration.Settings.CustomerUser.StoreIpAddresses">
    <Value>Store IP addresses</Value>
  </LocaleResource>
  <LocaleResource Name="Admin.Configuration.Settings.CustomerUser.StoreIpAddresses.Hint">
    <Value>When enabled, IP addresses of customers will be stored. When disabled, it can improved performance. Furthermore, it''s prohibited to store IP addresses in some countries (private customer data).</Value>
  </LocaleResource>
</Language>
'

CREATE TABLE #LocaleStringResourceTmp
	(
		[ResourceName] [nvarchar](200) NOT NULL,
		[ResourceValue] [nvarchar](max) NOT NULL
	)

INSERT INTO #LocaleStringResourceTmp (ResourceName, ResourceValue)
SELECT	nref.value('@Name', 'nvarchar(200)'), nref.value('Value[1]', 'nvarchar(MAX)')
FROM	@resources.nodes('//Language/LocaleResource') AS R(nref)

--do it for each existing language
DECLARE @ExistingLanguageID int
DECLARE cur_existinglanguage CURSOR FOR
SELECT [ID]
FROM [Language]
OPEN cur_existinglanguage
FETCH NEXT FROM cur_existinglanguage INTO @ExistingLanguageID
WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @ResourceName nvarchar(200)
	DECLARE @ResourceValue nvarchar(MAX)
	DECLARE cur_localeresource CURSOR FOR
	SELECT ResourceName, ResourceValue
	FROM #LocaleStringResourceTmp
	OPEN cur_localeresource
	FETCH NEXT FROM cur_localeresource INTO @ResourceName, @ResourceValue
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF (EXISTS (SELECT 1 FROM [LocaleStringResource] WHERE LanguageID=@ExistingLanguageID AND ResourceName=@ResourceName))
		BEGIN
			UPDATE [LocaleStringResource]
			SET [ResourceValue]=@ResourceValue
			WHERE LanguageID=@ExistingLanguageID AND ResourceName=@ResourceName
		END
		ELSE 
		BEGIN
			INSERT INTO [LocaleStringResource]
			(
				[LanguageId],
				[ResourceName],
				[ResourceValue]
			)
			VALUES
			(
				@ExistingLanguageID,
				@ResourceName,
				@ResourceValue
			)
		END
		
		IF (@ResourceValue is null or @ResourceValue = '')
		BEGIN
			DELETE [LocaleStringResource]
			WHERE LanguageID=@ExistingLanguageID AND ResourceName=@ResourceName
		END
		
		FETCH NEXT FROM cur_localeresource INTO @ResourceName, @ResourceValue
	END
	CLOSE cur_localeresource
	DEALLOCATE cur_localeresource


	--fetch next language identifier
	FETCH NEXT FROM cur_existinglanguage INTO @ExistingLanguageID
END
CLOSE cur_existinglanguage
DEALLOCATE cur_existinglanguage

DROP TABLE #LocaleStringResourceTmp
GO

--delete setting
DELETE FROM [Setting]
WHERE [Name] = N'externalauthenticationsettings.autoregisterenabled'
GO


--new setting
IF NOT EXISTS (SELECT 1 FROM [Setting] WHERE [name] = N'customersettings.storeipaddresses')
BEGIN
	INSERT [Setting] ([Name], [Value], [StoreId])
	VALUES (N'customersettings.storeipaddresses', N'True', 0)
END
GO

--drop column
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=object_id('[ScheduleTask]') and NAME='LeasedByMachineName')
BEGIN
	ALTER TABLE [ScheduleTask] DROP COLUMN [LeasedByMachineName]
END
GO

--drop column
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=object_id('[ScheduleTask]') and NAME='LeasedUntilUtc')
BEGIN
	ALTER TABLE [ScheduleTask] DROP COLUMN [LeasedUntilUtc]
END
GO
