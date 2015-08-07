-- =============================================
-- Recurses through Active Directory users and provides management breakdown
-- Modified: 04-22-2015 Ryan DeVries
-- =============================================

DROP PROCEDURE #usp_getuserorgtree
GO
CREATE PROCEDURE #usp_getuserorgtree @USERSAM VARCHAR(20)
AS
	-- Pull User information from AD linked Server into #tmpADUsers
	SELECT samAccountName, displayName, Manager, Department, distinguishedname
	INTO #tmpADUsers
	FROM OPENQUERY(ADSI, 'SELECT samAccountName, displayName, Manager, Department, distinguishedname 
	FROM ''LDAP://OU=Org,DC=Domain,DC=TLD'' 
	WHERE objectClass=''user''AND objectClass<>''computer'' 
	')

	-- Link full manager information to users into #tmpADUsers2
	SELECT usr.displayName AS [UserDisplay], usr.samaccountname AS [UserSAM], usr.department AS [UserDept], mgr.displayname AS [ManagerDisplay], mgr.samaccountname AS [ManagerSAM] 
	INTO #tmpADUsers2
	FROM #tmpADUsers AS [usr]
	LEFT OUTER JOIN #tmpADUsers AS [mgr] ON usr.manager = mgr.distinguishedname

	-- Recurse up the user heirarchy, starting at specified user
	;WITH Emp_CTE AS (
		-- Seed CTE with information about specified user
		SELECT UserDisplay, UserSAM, UserDept, ManagerDisplay, ManagerSAM, 0 AS Level
		FROM #tmpADUsers2
		WHERE UserSAM = @USERSAM
		UNION ALL
		-- Recurse up to the top level by joining previous results on the manager's SAM account
		SELECT mgr.UserDisplay, mgr.UserSAM, mgr.UserDept, mgr.ManagerDisplay, mgr.ManagerSAM, usr.Level+1 AS Level
		FROM #tmpADUsers2 mgr
		INNER JOIN Emp_CTE usr ON mgr.UserSAM = usr.ManagerSAM
	)

	-- Display results of user and management stucture above them
	SELECT UserDisplay, UserDept, CASE Level WHEN 0 THEN 'Searched' ELSE 'Manager-' + CAST(Level AS VARCHAR) END AS Level
	FROM Emp_CTE
	UNION ALL
	-- Attach Peers to results
	SELECT UserDisplay, UserDept, 'Peer' AS Level
	FROM #tmpADUsers2
	WHERE ManagerSAM = (SELECT ManagerSAM FROM #tmpADUsers2 WHERE UserSAM = @USERSAM) AND UserSAM <> @USERSAM
	ORDER BY Level, UserDisplay

	-- Clean up
	DROP TABLE #tmpADUsers
	DROP TABLE #tmpADUsers2
GO

-- Test
EXECUTE #usp_getuserorgtree 'test'
GO
