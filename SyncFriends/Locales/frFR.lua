local L = LibStub("AceLocale-3.0"):NewLocale("SyncFriends", "frFR")
if not L then return end

L["Action"] = true
L["Added %s"] = "%s ajouté"
L["addition"] = "ajout"
L["A friend"] = "Un ami"
L[ [=[An alt
]=] ] = "Un alt"
L["Auto-add alts"] = "Ajout des alts"
L["Auto-export"] = "Export automatique"
L["Auto-forget"] = "Oubli automatique"
L["Auto-import"] = "Import automatique"
L["Auto-remove guildmates"] = "Suppression des guildés"
L["Character override"] = "Configuration personnage"
L["Dump"] = true
L["Dumps sync pool to default chat window"] = "Affiche les données de synchronisation dans la fenêtre de discussion"
L["Dump start"] = "Début du dump"
L["Empties the content of the sync pool"] = "Efface les données de synchronisation"
L["Flush"] = "Vider"
L["Forget"] = "Oublier"
L["Forget about playerName (but don't mark him for removal)"] = "Oublier playerName (mais ne pas le marquer pour suppression)"
L["Forgetting about %s"] = "Oubli de %s"
L["Friends"] = "Amis"
L["Global setting"] = "Configuration générale"
L["It's me !"] = "C'est moi !"
L["Known by"] = "Connu par"
L["Manually trigger a synchronisation with sync pool"] = "Déclencher une synchronisation manuellement"
L["Marking new %s for %s"] = "Ajoute %s pour %s"
L["Marking %s for %s"] = "Marque %s pour %s"
L["Note"] = true
L["Options"] = true
L["Pool flushed"] = "Données de synchronisation effacées"
L["Register playerName for addition (default) or removal"] = "Définir playerName pour ajout (\"add\", défaut) ou suppression (\"remove\")"
L["removal"] = "suppression"
L["Removed %s"] = "%s supprimé"
L["Replacing %s note '%s' with '%s'"] = "Replacement de la note de %s '%s' par '%s'"
L["Skip given player name in sync"] = "Ignore le joueur donné dans la synchronisation"
L["skipping"] = "passer"
L["Sync"] = true
L["Sync data"] = "Données de synchronisation"
L["SyncFriends must be configured before it does anything"] = "SyncFriends ne fait rien tant qu'il n'est pas configuré"
L["Sync notes"] = "Synchoniser les notes"
L["Unknown"] = "Inconnu"
L["UNKNOWN ACTION"] = "ACTION INCONNUE"
L["Unknown action %s"] = "Action %s inconnue"
L["Unknown action %s for %s, skipping"] = "Action inconnue %s pour %s, ignorée"
L["Unknown scope %s"] = "Portée d'option %s inconnue"
L["Use global note"] = "Utiliser la note globale"
L["Warning: Some friend's data isn't loaded after two (or more) refresh requests. Syncfriends will need more time to start."] = "Avertisement: Les informations de certains amis n'ont pas été chargées après deux (ou plus) demandes. SyncFriends a besoin de plus de temps pour démarrer."
L["Whether alts should be added to other alts' friend lists"] = "Si vos personnages doivent être amis les uns des autres."
L["Whether current character should use global note for this character"] = "Si le personnage courant doit utiliser la note globale pour ce personnage"
L["Whether friends in current alt's guild should be removed from its friend list (they will be added back when they or the alt leaves the quild)."] = "Si les amis de l'alt doivent être supprimés tant qu'ils sont dans la même guilde que l'alt."
L["Whether friends should be forgotten about when no alt knows them anymore"] = "Si des amis peuvent être oubliés quand aucun personnage ne les a dans sa liste d'amis"
L["Whether friends should be imported upon startup"] = "Si les amis doivent êtres importés au démarrage"
L["Whether friends should be made known to synchronisation upon startup, addition and removal"] = "Si les données de synchronisation doivent être mises à jour au démarrage, à l'ajout et à la suppression d'amis"
L["Whether notes should be synchronised along with friends"] = "Synchroniser les notes en même temps que les amis."
L["You have reached the maximum number of friends, could not add %s"] = "Vous avez atteint le nombre maximum d'amis, impossible d'ajouter %s"
