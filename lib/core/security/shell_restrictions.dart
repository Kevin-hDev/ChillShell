// =============================================================================
// FIX-007 — Shell Restrictions (avertissements sur commandes sensibles)
// =============================================================================
// Probleme corrige : GAP-007
// Le shell local etait lance sans aucune restriction. Un attaquant avec acces
// physique pouvait executer rm -rf /, mkfs, dd, ou d'autres commandes
// destructives sans aucun avertissement ni trace.
//
// Choix de conception : PAS de blocage automatique.
// Le shell local de ChillShell est un outil de debug — bloquer des commandes
// casserait des cas d'usage legitimes (ex: un admin qui fait volontairement
// un dd ou un shutdown). On applique donc :
//   - Detection -> WARNING visible dans l'UI
//   - Trace dans l'audit log (pour detection d'incidents post-mortem)
//   - Assainissement de l'environnement shell (LD_PRELOAD, PATH restreint)
//
// INTEGRATION:
// 1. Dans local_shell_service.dart:write(), avant d'envoyer au PTY :
//    if (ShellRestrictions.isSensitiveCommand(data)) {
//      AuditLogService.log('SENSITIVE_CMD', data.substring(0, 50));
//      // Afficher getWarningMessage(data) dans l'UI
//    }
// 2. Dans startShell(), passer sanitizeShellEnvironment(env) comme
//    environnement au Pty.start().
// =============================================================================

// ---------------------------------------------------------------------------
// ShellRestrictions
// ---------------------------------------------------------------------------
/// Detecte les commandes shell dangereuses et assainit l'environnement.
///
/// Principle of least privilege pour le shell local :
/// - Restriction du PATH aux repertoires officiels
/// - Suppression des variables d'environnement qui permettent le hijacking
/// - Detection des patterns de commandes destructives
class ShellRestrictions {
  // -------------------------------------------------------------------------
  // Liste des patterns de commandes sensibles
  // -------------------------------------------------------------------------
  // Chaque entree est une sous-chaine recherchee dans la commande.
  // Les espaces dans les patterns sont intentionnels (evite les faux positifs).
  // Exemples :
  //   'rm -rf'  -> detecte 'rm -rf /', 'rm -rf /home', etc.
  //   'dd if='  -> detecte 'dd if=/dev/zero of=/dev/sda', etc.
  static const List<String> _sensitivePatterns = [
    'rm -rf',           // Suppression recursive forcee
    'rm -fr',           // Variante de rm -rf
    'mkfs',             // Formatage de partition
    'dd if=',           // Copie directe de blocs (risque d'ecrasement disque)
    'dd of=',           // Ecriture directe sur un peripherique
    'shutdown',         // Arret du systeme
    'reboot',           // Redemarrage du systeme
    'halt',             // Arret immediat
    'poweroff',         // Arret via systemd
    'init 0',           // Arret via SysV init
    'init 6',           // Redemarrage via SysV init
    'systemctl poweroff',   // Arret via systemd
    'systemctl reboot',     // Redemarrage via systemd
    'systemctl halt',       // Arret immediat via systemd
    ':(){',             // Fork bomb (syntaxe bash) -- detecte :(){ :|:& };:
    ':()',              // Variante fork bomb
    'chmod -R 777',     // Retrait de tous les droits (escalade de privileges)
    'chmod -R 000',     // Suppression de tous les droits
    'chown -R root',    // Changement recursif du proprietaire vers root
    '> /dev/sda',       // Ecrasement direct du disque
    '> /dev/nvme',      // Ecrasement direct d'un SSD NVMe
    '/dev/urandom > /', // Ecriture de donnees aleatoires sur le systeme
    'shred -u',         // Destruction securisee de fichiers
    'wipefs',           // Effacement des signatures de systeme de fichiers
    'fdisk',            // Outil de partitionnement interactif
    'parted',           // Outil de partitionnement
    'cryptsetup luksFormat', // Reformatage d'un volume chiffre
    'lvremove',         // Suppression de volume logique
    'vgremove',         // Suppression de groupe de volumes
    'pvremove',         // Suppression de volume physique
    'iptables -F',      // Vidage de toutes les regles firewall
    'ufw reset',        // Reset du firewall UFW
    'passwd root',      // Changement du mot de passe root
    'usermod -p',       // Modification directe du hash mot de passe
  ];

  // -------------------------------------------------------------------------
  // Variables d'environnement dangereuses a supprimer
  // -------------------------------------------------------------------------
  static const List<String> _dangerousEnvVars = [
    'LD_PRELOAD',       // Precharge une librairie arbitraire (hijacking)
    'LD_LIBRARY_PATH',  // Redirige la recherche de librairies (hijacking)
    'LD_AUDIT',         // Audit de la liaison dynamique (fuite d'info)
    'LD_DEBUG',         // Debug de la liaison dynamique (fuite d'info)
    'DYLD_INSERT_LIBRARIES', // Equivalent macOS de LD_PRELOAD
    'DYLD_LIBRARY_PATH',     // Equivalent macOS de LD_LIBRARY_PATH
    'PYTHONPATH',       // Peut rediriger les imports Python
    'RUBYLIB',          // Peut rediriger les imports Ruby
    'PERL5LIB',         // Peut rediriger les imports Perl
    'NODE_PATH',        // Peut rediriger les imports Node.js
  ];

  // -------------------------------------------------------------------------
  // PATH securise (repertoires de confiance uniquement)
  // -------------------------------------------------------------------------
  static const String _securePath =
      '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin';

  // =========================================================================
  // isSensitiveCommand()
  // =========================================================================
  /// Verifie si [input] contient un pattern de commande dangereuse.
  ///
  /// La detection est basee sur des sous-chaines (pas de regex) pour etre
  /// rapide et eviter les faux negatifs dus a des variantes d'espacement.
  ///
  /// Retourne true si au moins un pattern est detecte.
  static bool isSensitiveCommand(String input) {
    // Normaliser l'entree : minuscules, supprimer les espaces multiples
    final normalized = input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    for (final pattern in _sensitivePatterns) {
      if (normalized.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  // =========================================================================
  // getWarningMessage()
  // =========================================================================
  /// Retourne un message d'avertissement si [command] est sensible.
  ///
  /// Retourne null si la commande n'est pas reconnue comme dangereuse.
  /// Le message est destine a l'affichage dans l'UI — pas au log technique.
  static String? getWarningMessage(String command) {
    if (!isSensitiveCommand(command)) return null;

    // Identifier le pattern specifique pour un message contextuel
    final normalized = command.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    if (normalized.contains('rm -rf') || normalized.contains('rm -fr')) {
      return 'Attention : suppression recursive forcee detectee. Cette commande peut effacer des donnees irreversiblement.';
    }
    if (normalized.contains('mkfs') || normalized.contains('wipefs') ||
        normalized.contains('fdisk') || normalized.contains('parted')) {
      return 'Attention : operation de formatage detectee. Cette commande peut detruire un systeme de fichiers.';
    }
    if (normalized.contains('shutdown') || normalized.contains('reboot') ||
        normalized.contains('halt') || normalized.contains('poweroff') ||
        normalized.contains('init 0') || normalized.contains('init 6')) {
      return 'Attention : commande d\'arret ou de redemarrage detectee.';
    }
    if (normalized.contains('dd if=') || normalized.contains('dd of=') ||
        normalized.contains('/dev/sda') || normalized.contains('/dev/nvme')) {
      return 'Attention : acces direct a un peripherique de stockage detecte.';
    }
    if (normalized.contains(':(){') || normalized.contains(':()')) {
      return 'Attention : pattern de fork bomb detecte. Cette commande peut saturer le systeme.';
    }
    if (normalized.contains('chmod -r') || normalized.contains('chown -r')) {
      return 'Attention : modification recursive des permissions detectee.';
    }
    if (normalized.contains('iptables -f') || normalized.contains('ufw reset')) {
      return 'Attention : reinitialisation du pare-feu detectee.';
    }

    // Message generique pour les autres cas
    return 'Attention : commande potentiellement dangereuse detectee.';
  }

  // =========================================================================
  // sanitizeShellEnvironment()
  // =========================================================================
  /// Retourne une copie assainie de [env] pour le lancement du shell local.
  ///
  /// Transformations appliquees :
  ///   1. Supprimer toutes les variables d'environnement dangereuses
  ///   2. Remplacer PATH par un PATH restreint aux repertoires de confiance
  ///
  /// [env] est generalement Platform.environment.
  static Map<String, String> sanitizeShellEnvironment(
    Map<String, String> env,
  ) {
    // Copier l'environnement pour ne pas modifier l'original
    final sanitized = Map<String, String>.from(env);

    // --- Supprimer les variables dangereuses ---
    for (final dangerous in _dangerousEnvVars) {
      sanitized.remove(dangerous);
    }

    // --- Restreindre le PATH ---
    sanitized['PATH'] = _securePath;

    // --- Forcer HOME si absent (evite les comportements imprevisibles) ---
    sanitized.putIfAbsent('HOME', () => '/tmp');

    return sanitized;
  }

  // =========================================================================
  // listSensitivePatterns()
  // =========================================================================
  /// Retourne la liste des patterns surveilles (lecture seule).
  /// Utile pour les tests et l'affichage dans une interface d'administration.
  static List<String> listSensitivePatterns() {
    return List.unmodifiable(_sensitivePatterns);
  }
}
