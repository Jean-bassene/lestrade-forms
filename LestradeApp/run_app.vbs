' Lance run_app.bat sans afficher de fenetre de commande
Set oShell = CreateObject("Wscript.Shell")
Dim batPath
batPath = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\")) & "run_app.bat"
oShell.Run Chr(34) & batPath & Chr(34), 0, False
