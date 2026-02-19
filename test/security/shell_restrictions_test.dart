// =============================================================================
// TEST FIX-007 — Shell Restrictions
// =============================================================================
// Tests unitaires pour ShellRestrictions.
//
// Pour lancer ces tests :
//   flutter test test/security/test_fix_007.dart
//
// Ces tests valident que :
//   1. rm -rf / est detecte comme sensible
//   2. ls -la N'est PAS sensible
//   3. dd if=/dev/zero est detecte
//   4. La fork bomb :(){ :|:& };: est detectee
//   5. sanitizeShellEnvironment supprime LD_PRELOAD
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

// Import du fichier teste
// import 'package:chillshell/core/security/fix_007_shell_restrictions.dart';

// ---------------------------------------------------------------------------
// Copie de ShellRestrictions pour les tests (independante du fichier source)
// ---------------------------------------------------------------------------
// En integration reelle, remplacer cette classe par l'import ci-dessus.

class TestShellRestrictions {
  static const List<String> _sensitivePatterns = [
    'rm -rf',
    'rm -fr',
    'mkfs',
    'dd if=',
    'dd of=',
    'shutdown',
    'reboot',
    'halt',
    'poweroff',
    'init 0',
    'init 6',
    'systemctl poweroff',
    'systemctl reboot',
    'systemctl halt',
    ':(){',
    ':()',
    'chmod -R 777',
    'chmod -R 000',
    'chown -R root',
    '> /dev/sda',
    '> /dev/nvme',
    '/dev/urandom > /',
    'shred -u',
    'wipefs',
    'fdisk',
    'parted',
    'cryptsetup luksFormat',
    'lvremove',
    'vgremove',
    'pvremove',
    'iptables -F',
    'ufw reset',
    'passwd root',
    'usermod -p',
  ];

  static const List<String> _dangerousEnvVars = [
    'LD_PRELOAD',
    'LD_LIBRARY_PATH',
    'LD_AUDIT',
    'LD_DEBUG',
    'DYLD_INSERT_LIBRARIES',
    'DYLD_LIBRARY_PATH',
    'PYTHONPATH',
    'RUBYLIB',
    'PERL5LIB',
    'NODE_PATH',
  ];

  static const String _securePath =
      '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin';

  static bool isSensitiveCommand(String input) {
    final normalized =
        input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    for (final pattern in _sensitivePatterns) {
      if (normalized.contains(pattern.toLowerCase())) return true;
    }
    return false;
  }

  static String? getWarningMessage(String command) {
    if (!isSensitiveCommand(command)) return null;
    return 'Attention : commande potentiellement dangereuse detectee.';
  }

  static Map<String, String> sanitizeShellEnvironment(
      Map<String, String> env) {
    final sanitized = Map<String, String>.from(env);
    for (final dangerous in _dangerousEnvVars) {
      sanitized.remove(dangerous);
    }
    sanitized['PATH'] = _securePath;
    sanitized.putIfAbsent('HOME', () => '/tmp');
    return sanitized;
  }

  static List<String> listSensitivePatterns() =>
      List.unmodifiable(_sensitivePatterns);
}

// =============================================================================
// TESTS
// =============================================================================
void main() {
  // ---------------------------------------------------------------------------
  // TEST 1 : rm -rf / est detecte comme sensible
  // ---------------------------------------------------------------------------
  group('Detection de rm -rf', () {
    test('rm -rf / est sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('rm -rf /'),
        isTrue,
        reason: 'rm -rf / doit etre detecte',
      );
    });

    test('rm -rf /home/user est sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('rm -rf /home/user'),
        isTrue,
      );
    });

    test('rm -fr / (variante) est sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('rm -fr /'),
        isTrue,
        reason: 'La variante rm -fr doit aussi etre detectee',
      );
    });

    test('rm -rf est sensible avec des espaces multiples', () {
      // Normalisation des espaces
      expect(
        TestShellRestrictions.isSensitiveCommand('rm  -rf  /'),
        isTrue,
        reason: 'Les espaces multiples ne doivent pas contourner la detection',
      );
    });

    test('rm -rf est sensible en majuscules (normalisation)', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('RM -RF /'),
        isTrue,
        reason: 'Les majuscules ne doivent pas contourner la detection',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 2 : ls -la N'est PAS sensible
  // ---------------------------------------------------------------------------
  group('Commandes inoffensives non detectees', () {
    test('ls -la n\'est PAS sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('ls -la'),
        isFalse,
        reason: 'ls -la est une commande de lecture normale',
      );
    });

    test('cd /home n\'est PAS sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('cd /home'),
        isFalse,
      );
    });

    test('cat /etc/hosts n\'est PAS sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('cat /etc/hosts'),
        isFalse,
      );
    });

    test('grep -r pattern . n\'est PAS sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('grep -r pattern .'),
        isFalse,
      );
    });

    test('git status n\'est PAS sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('git status'),
        isFalse,
      );
    });

    test('flutter run n\'est PAS sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('flutter run'),
        isFalse,
      );
    });

    test('pwd n\'est PAS sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('pwd'),
        isFalse,
      );
    });

    test('echo hello n\'est PAS sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('echo hello'),
        isFalse,
      );
    });

    test('mkdir nouveau_dossier n\'est PAS sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('mkdir nouveau_dossier'),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 3 : dd if=/dev/zero est detecte
  // ---------------------------------------------------------------------------
  group('Detection de dd (copie directe de blocs)', () {
    test('dd if=/dev/zero of=/dev/sda est sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand(
            'dd if=/dev/zero of=/dev/sda'),
        isTrue,
        reason: 'dd if= doit etre detecte (effacement de disque)',
      );
    });

    test('dd if=/dev/urandom of=/dev/sda est sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand(
            'dd if=/dev/urandom of=/dev/sda'),
        isTrue,
      );
    });

    test('dd if=/dev/sda of=backup.img est sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand(
            'dd if=/dev/sda of=backup.img'),
        isTrue,
        reason: 'dd if= est toujours detecte meme pour une sauvegarde',
      );
    });

    test('dd of=/dev/sdb est sensible (ecriture directe)', () {
      expect(
        TestShellRestrictions.isSensitiveCommand('dd of=/dev/sdb'),
        isTrue,
      );
    });

    test('dd count=1 n\'a pas if= -> non detecte comme dd', () {
      // 'dd count=1' seul n'a pas de pattern 'dd if=' ou 'dd of='
      // Note: 'shutdown' n'est pas dans la commande donc pas detecte
      expect(
        TestShellRestrictions.isSensitiveCommand('dd count=1'),
        isFalse,
        reason: 'dd sans if= ni of= n\'est pas forcement dangereux',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 4 : Fork bomb :(){ :|:& };: est detectee
  // ---------------------------------------------------------------------------
  group('Detection de fork bomb', () {
    test(':(){ :|:& };: est sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand(':(){ :|:& };:'),
        isTrue,
        reason: 'La fork bomb classique doit etre detectee',
      );
    });

    test(':(){  :|:&  };: (espaces variables) est sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand(':(){  :|:&  };:'),
        isTrue,
        reason: 'Les espaces variables ne doivent pas contourner la detection',
      );
    });

    test('Variante fork bomb avec :() est sensible', () {
      expect(
        TestShellRestrictions.isSensitiveCommand(':()'),
        isTrue,
        reason: ':() est un pattern de fork bomb',
      );
    });

    test('Fonction Bash normale avec { } n\'est pas necessairement sensible',
        () {
      // Une fonction Bash normale comme 'myfunc(){ echo hello; }' ne doit
      // pas etre detestee si elle ne contient pas les patterns specifiques
      expect(
        TestShellRestrictions.isSensitiveCommand('myfunc(){ echo hello; }'),
        isFalse,
        reason:
            'Une fonction Bash avec un nom normal ne doit pas etre detectee',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 5 : sanitizeShellEnvironment supprime LD_PRELOAD
  // ---------------------------------------------------------------------------
  group('sanitizeShellEnvironment supprime les variables dangereuses', () {
    test('Supprime LD_PRELOAD', () {
      final env = {
        'LD_PRELOAD': '/malicious/lib.so',
        'HOME': '/home/user',
        'TERM': 'xterm-256color',
      };

      final sanitized = TestShellRestrictions.sanitizeShellEnvironment(env);

      expect(sanitized.containsKey('LD_PRELOAD'), isFalse,
          reason: 'LD_PRELOAD doit etre supprime');
    });

    test('Supprime LD_LIBRARY_PATH', () {
      final env = {
        'LD_LIBRARY_PATH': '/malicious/libs',
        'HOME': '/home/user',
      };

      final sanitized = TestShellRestrictions.sanitizeShellEnvironment(env);
      expect(sanitized.containsKey('LD_LIBRARY_PATH'), isFalse);
    });

    test('Supprime DYLD_INSERT_LIBRARIES (macOS)', () {
      final env = {
        'DYLD_INSERT_LIBRARIES': '/evil.dylib',
      };

      final sanitized = TestShellRestrictions.sanitizeShellEnvironment(env);
      expect(sanitized.containsKey('DYLD_INSERT_LIBRARIES'), isFalse);
    });

    test('Supprime toutes les variables dangereuses en une passe', () {
      final env = {
        'LD_PRELOAD': '/evil.so',
        'LD_LIBRARY_PATH': '/evil/libs',
        'LD_AUDIT': '/evil/audit.so',
        'LD_DEBUG': 'all',
        'DYLD_INSERT_LIBRARIES': '/evil.dylib',
        'DYLD_LIBRARY_PATH': '/evil/dylibs',
        'PYTHONPATH': '/evil/python',
        'RUBYLIB': '/evil/ruby',
        'PERL5LIB': '/evil/perl',
        'NODE_PATH': '/evil/node',
        'HOME': '/home/user', // Doit rester
        'TERM': 'xterm-256color', // Doit rester
      };

      final sanitized = TestShellRestrictions.sanitizeShellEnvironment(env);

      // Toutes les variables dangereuses sont supprimees
      for (final dangerous in [
        'LD_PRELOAD',
        'LD_LIBRARY_PATH',
        'LD_AUDIT',
        'LD_DEBUG',
        'DYLD_INSERT_LIBRARIES',
        'DYLD_LIBRARY_PATH',
        'PYTHONPATH',
        'RUBYLIB',
        'PERL5LIB',
        'NODE_PATH',
      ]) {
        expect(sanitized.containsKey(dangerous), isFalse,
            reason: '$dangerous doit etre supprimee');
      }

      // Les variables inoffensives sont conservees
      expect(sanitized['HOME'], equals('/home/user'),
          reason: 'HOME doit etre conserve');
      expect(sanitized['TERM'], equals('xterm-256color'),
          reason: 'TERM doit etre conserve');
    });

    test('Remplace PATH par un PATH restreint', () {
      final env = {
        'PATH': '/usr/bin:/bin:/malicious/bin:/tmp/hack',
        'HOME': '/home/user',
      };

      final sanitized = TestShellRestrictions.sanitizeShellEnvironment(env);

      expect(sanitized['PATH'],
          equals('/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin'),
          reason: 'PATH doit etre remplace par le PATH securise');
      expect(sanitized['PATH']!.contains('/malicious'), isFalse,
          reason: 'Le PATH malicieux doit etre elimine');
      expect(sanitized['PATH']!.contains('/tmp'), isFalse,
          reason: '/tmp ne doit pas etre dans le PATH');
    });

    test('N\'ecrase pas l\'environnement original (copie defensive)', () {
      final original = {
        'LD_PRELOAD': '/evil.so',
        'HOME': '/home/user',
      };

      TestShellRestrictions.sanitizeShellEnvironment(original);

      // L'original ne doit pas etre modifie
      expect(original.containsKey('LD_PRELOAD'), isTrue,
          reason: 'sanitizeShellEnvironment ne doit pas modifier le Map original');
    });

    test('Ajoute HOME=/tmp si HOME est absent', () {
      final env = <String, String>{
        'PATH': '/usr/bin',
        // HOME absent
      };

      final sanitized = TestShellRestrictions.sanitizeShellEnvironment(env);
      expect(sanitized.containsKey('HOME'), isTrue,
          reason: 'HOME doit etre ajoute avec /tmp si absent');
      expect(sanitized['HOME'], equals('/tmp'));
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 6 : getWarningMessage() retourne null pour les commandes inoffensives
  // ---------------------------------------------------------------------------
  group('getWarningMessage()', () {
    test('Retourne null pour ls -la', () {
      expect(TestShellRestrictions.getWarningMessage('ls -la'), isNull);
    });

    test('Retourne un message non-null pour rm -rf', () {
      expect(
          TestShellRestrictions.getWarningMessage('rm -rf /'), isNotNull);
    });

    test('Retourne un message non-null pour shutdown', () {
      expect(
          TestShellRestrictions.getWarningMessage('sudo shutdown -h now'),
          isNotNull);
    });

    test('Le message ne contient pas de details internes du systeme', () {
      final msg =
          TestShellRestrictions.getWarningMessage('rm -rf /');
      expect(msg, isNotNull);
      // Le message ne doit pas fuiter de chemins internes ou stack traces
      expect(msg!.contains('/home'), isFalse);
      expect(msg.contains('Exception'), isFalse);
      expect(msg.contains('StackTrace'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 7 : Autres commandes sensibles importantes
  // ---------------------------------------------------------------------------
  group('Detection des autres commandes sensibles', () {
    test('mkfs est sensible', () {
      expect(
          TestShellRestrictions.isSensitiveCommand('mkfs.ext4 /dev/sdb1'),
          isTrue);
    });

    test('chmod -R 777 est sensible', () {
      expect(
          TestShellRestrictions.isSensitiveCommand('chmod -R 777 /'),
          isTrue);
    });

    test('systemctl poweroff est sensible', () {
      expect(
          TestShellRestrictions.isSensitiveCommand('systemctl poweroff'),
          isTrue);
    });

    test('wipefs est sensible', () {
      expect(
          TestShellRestrictions.isSensitiveCommand('wipefs -a /dev/sda'),
          isTrue);
    });

    test('iptables -F est sensible', () {
      expect(
          TestShellRestrictions.isSensitiveCommand('iptables -F'),
          isTrue);
    });

    test('passwd root est sensible', () {
      expect(
          TestShellRestrictions.isSensitiveCommand('passwd root'),
          isTrue);
    });

    test('shred -u est sensible', () {
      expect(
          TestShellRestrictions.isSensitiveCommand('shred -u fichier.conf'),
          isTrue);
    });
  });
}
