import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../services/storage_service.dart';

class TerminalState {
  final List<Command> commands;
  final String currentInput;
  final String? ghostText;
  final List<String> commandHistory;
  final int historyIndex;
  final DateTime? lastCommandStart;
  final Duration? lastExecutionTime;
  final String? currentPath;

  const TerminalState({
    this.commands = const [],
    this.currentInput = '',
    this.ghostText,
    this.commandHistory = const [],
    this.historyIndex = -1,
    this.lastCommandStart,
    this.lastExecutionTime,
    this.currentPath,
  });

  TerminalState copyWith({
    List<Command>? commands,
    String? currentInput,
    String? ghostText,
    List<String>? commandHistory,
    int? historyIndex,
    DateTime? lastCommandStart,
    Duration? lastExecutionTime,
    String? currentPath,
  }) {
    return TerminalState(
      commands: commands ?? this.commands,
      currentInput: currentInput ?? this.currentInput,
      ghostText: ghostText,
      commandHistory: commandHistory ?? this.commandHistory,
      historyIndex: historyIndex ?? this.historyIndex,
      lastCommandStart: lastCommandStart ?? this.lastCommandStart,
      lastExecutionTime: lastExecutionTime ?? this.lastExecutionTime,
      currentPath: currentPath ?? this.currentPath,
    );
  }
}

class TerminalNotifier extends StateNotifier<TerminalState> {
  TerminalNotifier() : super(const TerminalState()) {
    _loadHistory();
  }

  final _uuid = const Uuid();
  final _storage = StorageService();

  /// Charge l'historique depuis le stockage persistant
  Future<void> _loadHistory() async {
    final history = await _storage.getCommandHistory();
    if (history.isNotEmpty) {
      state = state.copyWith(commandHistory: history);
    }
  }

  void setInput(String input, {bool resetHistory = true}) {
    final ghost = _getSuggestion(input);
    state = state.copyWith(
      currentInput: input,
      ghostText: ghost,
      historyIndex: resetHistory ? -1 : state.historyIndex,
    );
  }

  void acceptGhostText() {
    if (state.ghostText != null) {
      state = state.copyWith(
        currentInput: state.currentInput + state.ghostText!,
        ghostText: null,
      );
    }
  }

  /// Patterns de commandes sensibles à ne JAMAIS enregistrer
  static const _sensitivePatterns = [
    // Mots de passe et authentification
    'password',
    'passwd',
    'secret',
    'token',
    'api_key',
    'apikey',
    'api-key',
    'auth',
    'credential',
    'private',
    // Commandes d'export de variables sensibles
    'export ',
    // SSH avec mot de passe inline
    'sshpass',
    // MySQL/PostgreSQL avec mot de passe
    '-p=',
    '--password=',
    'PGPASSWORD=',
    'MYSQL_PWD=',
    // AWS/Cloud credentials
    'AWS_SECRET',
    'AZURE_',
    'GCP_',
    'GOOGLE_APPLICATION_CREDENTIALS',
    // Autres
    '.env',
    'id_rsa',
    'id_ed25519',
  ];

  /// Vérifie si une commande contient des données sensibles
  bool _isSensitiveCommand(String command) {
    final lower = command.toLowerCase();
    for (final pattern in _sensitivePatterns) {
      if (lower.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Ajoute une commande à l'historique et sauvegarde
  /// Note: Utiliser addToHistoryIfSuccess() pour vérifier le code retour avant
  void addToHistory(String command) {
    if (command.trim().isEmpty) return;

    // NE JAMAIS enregistrer les commandes sensibles (mots de passe, tokens, etc.)
    if (_isSensitiveCommand(command)) {
      debugPrint('SECURITY: Sensitive command NOT added to history');
      return;
    }

    // Éviter les doublons consécutifs
    if (state.commandHistory.isNotEmpty &&
        state.commandHistory.last == command) {
      return;
    }

    final newHistory = [...state.commandHistory, command];
    // Limiter l'historique à 200 commandes
    if (newHistory.length > 200) {
      newHistory.removeAt(0);
    }

    state = state.copyWith(commandHistory: newHistory);

    // Sauvegarder l'historique de manière persistante
    _storage.saveCommandHistory(newHistory);
  }

  /// Efface complètement l'historique des commandes (utile pour reset après pollution)
  Future<void> clearCommandHistory() async {
    state = state.copyWith(commandHistory: []);
    await _storage.saveCommandHistory([]);
    debugPrint('Command history cleared');
  }

  /// Commande en attente de validation (avant vérification via output)
  String? _pendingCommand;
  DateTime? _pendingCommandTime;
  bool _pendingCommandValidated = false;

  /// SÉCURITÉ: Indique si le shell attend une saisie sensible (mot de passe, passphrase, etc.)
  /// Quand true, l'input suivant NE SERA PAS enregistré dans l'historique
  bool _isWaitingForSensitiveInput = false;

  /// Patterns qui indiquent que le shell attend un mot de passe ou autre donnée sensible
  static const _passwordPromptPatterns = [
    // Sudo
    '[sudo] password',
    'password for',
    'mot de passe',
    // SSH
    'passphrase',
    'enter passphrase',
    'ssh password',
    // GPG
    'enter pin',
    'gpg: ',
    // Generic
    'password:',
    'password :',
    'secret:',
    'token:',
    'api key:',
    // MySQL/PostgreSQL
    'enter password',
    // Docker
    'login password',
    // Git credentials
    'password for \'',
    'username for',
    // Confirmation dangereuse
    'are you sure',
    'y/n',
    '(yes/no)',
  ];

  /// Patterns d'erreur courants dans les shells
  static const _errorPatterns = [
    // English - Basic errors
    'command not found',
    'No such file or directory',
    'Permission denied',
    'is not recognized',
    'cannot access',
    'does not exist',
    'not a directory',
    'is a directory',
    'syntax error',
    'invalid option',
    'unknown option',
    'missing argument',
    'too few arguments',
    'bad substitution',
    'unbound variable',
    ': not found',
    'No command',
    'unable to',
    'Operation not permitted',
    'segmentation fault',
    'Killed',
    'error:',
    'Error:',
    'failed',
    'cannot find',
    'cannot execute',
    'not permitted',

    // French - Ubuntu/Debian suggestion messages
    "n'a pas été trouvée",  // "La commande « htopi » n'a pas été trouvée"
    'pas été trouvé',       // Variante masculine
    'Aucun fichier ou dossier de ce nom',
    'commande introuvable',
    "n'existe pas",
    'Erreur',
    'Permission non accordée',
    'opération non permise',

    // Zsh specific
    'zsh: command not found',
    'zsh: no such file or directory',

    // Bash specific
    'bash: ',  // Préfixe d'erreur bash (ex: "bash: htopi: command not found")
  ];

  /// Stocke une commande en attente de validation
  /// SÉCURITÉ: Si on attend une saisie sensible (mot de passe), on n'enregistre RIEN
  void setPendingCommand(String command) {
    // SÉCURITÉ CRITIQUE: Si le shell attend un mot de passe, on n'enregistre PAS l'input
    if (_isWaitingForSensitiveInput) {
      debugPrint('SECURITY: Sensitive input detected, NOT saving to history');
      _isWaitingForSensitiveInput = false; // Reset pour le prochain input
      _pendingCommand = null;
      _pendingCommandTime = null;
      _pendingCommandValidated = false;
      return; // NE PAS enregistrer cette commande
    }

    _pendingCommand = command;
    _pendingCommandTime = DateTime.now();
    _pendingCommandValidated = false;
  }

  /// Appelé quand on reçoit de la sortie du terminal
  /// 1. Détecte si le shell demande un mot de passe (pour ne pas enregistrer l'input suivant)
  /// 2. Vérifie si la sortie contient une erreur pour la commande en attente
  void onTerminalOutput(String output) {
    final lowerOutput = output.toLowerCase();

    // SÉCURITÉ: Détecter si le shell demande un mot de passe ou autre donnée sensible
    for (final pattern in _passwordPromptPatterns) {
      if (lowerOutput.contains(pattern.toLowerCase())) {
        _isWaitingForSensitiveInput = true;
        debugPrint('SECURITY: Password prompt detected ("$pattern"), next input will NOT be saved');
        // Annuler aussi la commande en attente si c'était une commande qui demande un password
        _pendingCommand = null;
        _pendingCommandTime = null;
        return;
      }
    }

    // Si pas de commande en attente, rien d'autre à faire
    if (_pendingCommand == null || _pendingCommandValidated) return;

    // Vérifier si la sortie contient un pattern d'erreur
    for (final pattern in _errorPatterns) {
      if (lowerOutput.contains(pattern.toLowerCase())) {
        // Erreur détectée → ne pas ajouter à l'historique
        debugPrint('ERROR DETECTED: "$pattern" in output, command "$_pendingCommand" NOT added to history');
        _pendingCommand = null;
        _pendingCommandTime = null;
        return;
      }
    }
  }

  /// Valide la commande en attente après le délai (si pas d'erreur détectée)
  void validatePendingCommandAfterDelay() {
    if (_pendingCommand == null || _pendingCommandValidated) return;

    // Vérifier que le délai est passé (500ms)
    if (_pendingCommandTime != null) {
      final elapsed = DateTime.now().difference(_pendingCommandTime!);
      if (elapsed.inMilliseconds >= 500) {
        // Pas d'erreur détectée après le délai → ajouter à l'historique
        debugPrint('No error detected for "${_pendingCommand}", adding to history');
        addToHistory(_pendingCommand!);
        _pendingCommandValidated = true;
        _pendingCommand = null;
        _pendingCommandTime = null;
      }
    }
  }

  /// Annule la commande en attente
  void cancelPendingCommand() {
    _pendingCommand = null;
    _pendingCommandTime = null;
    _pendingCommandValidated = false;
  }

  /// Navigue vers la commande précédente dans l'historique
  String? previousCommand() {
    if (state.commandHistory.isEmpty) return null;

    int newIndex = state.historyIndex;
    if (newIndex == -1) {
      newIndex = state.commandHistory.length - 1;
    } else if (newIndex > 0) {
      newIndex--;
    }

    state = state.copyWith(historyIndex: newIndex);
    return state.commandHistory[newIndex];
  }

  /// Navigue vers la commande suivante dans l'historique
  String? nextCommand() {
    if (state.commandHistory.isEmpty || state.historyIndex == -1) return null;

    int newIndex = state.historyIndex + 1;
    if (newIndex >= state.commandHistory.length) {
      state = state.copyWith(historyIndex: -1);
      return '';
    }

    state = state.copyWith(historyIndex: newIndex);
    return state.commandHistory[newIndex];
  }

  void executeCommand(String command) {
    if (command.trim().isEmpty) return;

    final cmd = Command(
      id: _uuid.v4(),
      command: command,
      timestamp: DateTime.now(),
      isRunning: true,
    );

    // Ajouter à l'historique
    addToHistory(command);

    state = state.copyWith(
      commands: [...state.commands, cmd],
      currentInput: '',
      ghostText: null,
      historyIndex: -1,
    );
  }

  void updateCommandOutput(String commandId, String output, {bool isComplete = false, Duration? executionTime}) {
    state = state.copyWith(
      commands: state.commands.map((cmd) {
        if (cmd.id == commandId) {
          return cmd.copyWith(
            output: output,
            isRunning: !isComplete,
            executionTime: executionTime ?? cmd.executionTime,
          );
        }
        return cmd;
      }).toList(),
    );
  }

  void clearHistory() {
    state = const TerminalState();
  }

  /// Marque le début d'une commande (pour calculer le temps d'exécution)
  void startCommand() {
    // Capturer le temps d'exécution de la commande précédente
    Duration? previousExecutionTime;
    if (state.lastCommandStart != null) {
      previousExecutionTime = DateTime.now().difference(state.lastCommandStart!);
    }

    state = state.copyWith(
      lastCommandStart: DateTime.now(),
      lastExecutionTime: previousExecutionTime,
    );
  }

  /// Met à jour le chemin courant
  void updatePath(String path) {
    state = state.copyWith(currentPath: path);
  }


  String? _getSuggestion(String input) {
    if (input.isEmpty) return null;

    final lower = input.toLowerCase().trim();

    // 1. Chercher d'abord dans l'historique des commandes (priorité maximale)
    for (final cmd in state.commandHistory.reversed) {
      if (cmd.toLowerCase().startsWith(lower) && cmd.length > input.length) {
        return cmd.substring(input.length);
      }
    }

    // 2. Liste de commandes complètes (triées par fréquence/importance)
    // L'algorithme suggère dès les premières lettres tapées
    const commands = <String>[
      // ══════════════════════════════════════════════════════════════════════
      // GIT - Les plus utilisées en premier
      // ══════════════════════════════════════════════════════════════════════
      'git status',
      'git add .',
      'git commit -m ""',
      'git push',
      'git push origin ',
      'git pull',
      'git pull origin ',
      'git checkout ',
      'git checkout -b ',
      'git branch',
      'git branch -d ',
      'git log --oneline',
      'git diff',
      'git merge ',
      'git rebase ',
      'git fetch --all',
      'git clone ',
      'git stash',
      'git stash pop',
      'git stash list',
      'git reset --hard HEAD',
      'git remote -v',
      'git tag ',
      'git cherry-pick ',
      'git revert ',
      'git blame ',
      'git show ',
      'git init',
      'git config --global ',

      // GitHub CLI
      'gh pr list',
      'gh pr create',
      'gh pr view',
      'gh pr checkout ',
      'gh issue list',
      'gh issue create',
      'gh repo clone ',
      'gh browse',
      'gh auth login',

      // ══════════════════════════════════════════════════════════════════════
      // NAVIGATION & FICHIERS
      // ══════════════════════════════════════════════════════════════════════
      'cd ',
      'cd ~/',
      'cd ..',
      'ls -la',
      'ls -al',
      'pwd',
      'cat ',
      'less ',
      'more ',
      'head -n 20 ',
      'tail -f ',
      'grep -r "" .',
      'rg ""',
      'find . -name ""',
      'fd ',
      'fzf',
      'mkdir -p ',
      'rm -rf ',
      'rmdir ',
      'cp -r ',
      'mv ',
      'touch ',
      'chmod +x ',
      'chmod 755 ',
      'chown ',
      'ln -s ',
      'file ',
      'stat ',
      'wc -l ',
      'sort ',
      'uniq ',
      'cut -d"" -f1',
      'tr ',
      'sed -i "" ',
      'awk \'{print \$1}\' ',
      'xargs ',
      'tee ',
      'tree -L 2',
      'du -sh *',
      'df -h',
      'tar -xzvf ',
      'tar -czvf ',
      'zip -r ',
      'unzip ',
      'gzip ',
      'gunzip ',
      'rsync -avz ',

      // ══════════════════════════════════════════════════════════════════════
      // NPM / NODE
      // ══════════════════════════════════════════════════════════════════════
      'npm run dev',
      'npm run build',
      'npm run start',
      'npm run test',
      'npm run lint',
      'npm install',
      'npm install -D ',
      'npm ci',
      'npm start',
      'npm test',
      'npm init -y',
      'npm update',
      'npm outdated',
      'npm audit fix',
      'npm cache clean --force',
      'npm uninstall ',
      'npm publish',
      'npm version patch',
      'node ',
      'node -v',
      'node --version',

      // npx
      'npx create-react-app ',
      'npx create-next-app ',
      'npx create-vite ',
      'npx tsc --init',
      'npx eslint --init',
      'npx prettier --write .',
      'npx prisma migrate dev',
      'npx prisma generate',
      'npx prisma studio',
      'npx playwright test',
      'npx cypress open',
      'npx jest',
      'npx vitest',
      'npx tailwindcss init',
      'npx shadcn-ui@latest add ',

      // Yarn
      'yarn dev',
      'yarn build',
      'yarn start',
      'yarn test',
      'yarn lint',
      'yarn install',
      'yarn add ',
      'yarn add -D ',
      'yarn remove ',
      'yarn upgrade',
      'yarn global add ',
      'yarn cache clean',
      'yarn why ',

      // pnpm
      'pnpm dev',
      'pnpm build',
      'pnpm test',
      'pnpm install',
      'pnpm add ',
      'pnpm add -D ',
      'pnpm run dev',
      'pnpm run build',
      'pnpm remove ',
      'pnpm store prune',

      // Bun
      'bun run dev',
      'bun run build',
      'bun dev',
      'bun build',
      'bun test',
      'bun install',
      'bun add ',
      'bun add -d ',
      'bun remove ',
      'bun create ',
      'bun init',
      'bun upgrade',

      // Deno
      'deno run ',
      'deno test',
      'deno fmt',
      'deno lint',
      'deno compile ',
      'deno task ',
      'deno install ',
      'deno cache ',

      // ══════════════════════════════════════════════════════════════════════
      // PYTHON
      // ══════════════════════════════════════════════════════════════════════
      'python ',
      'python3 ',
      'python -m venv venv',
      'python3 -m venv venv',
      'python -m pip install ',
      'python3 -m pip install ',
      'pip install ',
      'pip install -r requirements.txt',
      'pip uninstall ',
      'pip freeze > requirements.txt',
      'pip list',
      'pip show ',
      'pip3 install ',
      'pipx install ',
      'source venv/bin/activate',
      'deactivate',
      'pytest -v',
      'pytest --cov',
      'uvicorn main:app --reload',
      'gunicorn ',
      'flask run',
      'django-admin startproject ',
      'python manage.py runserver',
      'python manage.py migrate',
      'python manage.py makemigrations',
      'poetry install',
      'poetry add ',
      'poetry run ',
      'poetry shell',
      'poetry update',
      'poetry build',
      'poetry publish',
      'pdm install',
      'pdm add ',
      'pdm run ',
      'uv pip install ',
      'uv venv',
      'uv sync',
      'uv run ',
      'ruff check .',
      'ruff format .',
      'black .',
      'mypy .',
      'flake8 .',
      'isort .',
      'bandit -r .',

      // ══════════════════════════════════════════════════════════════════════
      // DOCKER
      // ══════════════════════════════════════════════════════════════════════
      'docker ps',
      'docker ps -a',
      'docker compose up -d',
      'docker compose down',
      'docker compose logs -f',
      'docker compose build',
      'docker compose pull',
      'docker compose restart',
      'docker compose exec ',
      'docker build -t ',
      'docker run -it ',
      'docker run -d ',
      'docker images',
      'docker logs -f ',
      'docker exec -it ',
      'docker stop ',
      'docker start ',
      'docker restart ',
      'docker rm ',
      'docker rmi ',
      'docker pull ',
      'docker push ',
      'docker tag ',
      'docker network ls',
      'docker volume ls',
      'docker system prune -a',
      'docker inspect ',
      'docker stats',
      'docker login',
      'docker logout',

      // Podman
      'podman ps -a',
      'podman run -it ',
      'podman build -t ',
      'podman images',
      'podman exec -it ',
      'podman logs -f ',
      'podman compose up -d',

      // ══════════════════════════════════════════════════════════════════════
      // KUBERNETES
      // ══════════════════════════════════════════════════════════════════════
      'kubectl get pods',
      'kubectl get pods -A',
      'kubectl get services',
      'kubectl get svc',
      'kubectl get deployments',
      'kubectl get nodes',
      'kubectl get namespaces',
      'kubectl get all',
      'kubectl get all -A',
      'kubectl describe pod ',
      'kubectl apply -f ',
      'kubectl delete pod ',
      'kubectl logs -f ',
      'kubectl exec -it ',
      'kubectl port-forward ',
      'kubectl scale deployment ',
      'kubectl rollout status ',
      'kubectl rollout restart ',
      'kubectl config get-contexts',
      'kubectl config use-context ',
      'kubectl create namespace ',
      'kubectl -n ',
      'kubectl top pods',
      'kubectl top nodes',
      'k9s',

      // Helm
      'helm install ',
      'helm upgrade ',
      'helm upgrade --install ',
      'helm list',
      'helm repo add ',
      'helm repo update',
      'helm search repo ',
      'helm uninstall ',
      'helm rollback ',
      'helm template ',
      'helm show values ',
      'helm pull ',
      'helm package ',
      'helm lint ',
      'helm dependency update',

      // minikube
      'minikube start',
      'minikube stop',
      'minikube delete',
      'minikube status',
      'minikube dashboard',
      'minikube tunnel',
      'minikube service ',
      'minikube addons list',

      // kind
      'kind create cluster',
      'kind delete cluster',
      'kind get clusters',

      // ══════════════════════════════════════════════════════════════════════
      // CLOUD (AWS, GCP, Azure)
      // ══════════════════════════════════════════════════════════════════════
      // AWS
      'aws s3 ls',
      'aws s3 cp ',
      'aws s3 sync ',
      'aws ec2 describe-instances',
      'aws lambda list-functions',
      'aws lambda invoke ',
      'aws ecs list-clusters',
      'aws eks list-clusters',
      'aws rds describe-db-instances',
      'aws iam list-users',
      'aws sts get-caller-identity',
      'aws configure',
      'aws --region ',
      'aws --profile ',

      // Google Cloud
      'gcloud auth login',
      'gcloud compute instances list',
      'gcloud projects list',
      'gcloud config set project ',
      'gcloud container clusters list',
      'gcloud functions list',
      'gcloud run services list',
      'gcloud app deploy',
      'gsutil ls ',
      'gsutil cp ',
      'gsutil mb ',
      'gsutil rsync ',

      // Azure
      'az login',
      'az account list',
      'az account set --subscription ',
      'az group list',
      'az vm list',
      'az storage ',
      'az aks get-credentials ',
      'az webapp ',
      'az functionapp ',
      'az acr login ',

      // ══════════════════════════════════════════════════════════════════════
      // TERRAFORM / ANSIBLE
      // ══════════════════════════════════════════════════════════════════════
      'terraform init',
      'terraform plan',
      'terraform apply',
      'terraform apply -auto-approve',
      'terraform destroy',
      'terraform destroy -auto-approve',
      'terraform validate',
      'terraform fmt',
      'terraform state list',
      'terraform output',
      'terraform show',
      'terraform refresh',
      'terraform import ',
      'terraform workspace list',
      'terraform workspace select ',
      'terraform workspace new ',

      'ansible -i inventory.ini all -m ping',
      'ansible all -m ping',
      'ansible-playbook ',
      'ansible-galaxy install ',
      'ansible-vault encrypt ',
      'ansible-vault decrypt ',

      'pulumi up',
      'pulumi destroy',
      'pulumi preview',
      'pulumi stack ls',
      'pulumi stack select ',
      'pulumi new ',
      'pulumi config set ',

      // ══════════════════════════════════════════════════════════════════════
      // SYSTÈME LINUX
      // ══════════════════════════════════════════════════════════════════════
      'sudo ',
      'su -',

      // APT (Debian/Ubuntu)
      'apt update',
      'apt upgrade',
      'apt install ',
      'apt remove ',
      'apt search ',
      'apt show ',
      'apt list --installed',
      'apt autoremove',
      'apt-get update',
      'apt-get install ',

      // DNF/YUM
      'dnf install ',
      'dnf update',
      'dnf search ',
      'dnf remove ',
      'dnf list installed',
      'yum install ',
      'yum update',

      // Pacman
      'pacman -S ',
      'pacman -Syu',
      'pacman -Q',
      'pacman -R ',
      'pacman -Ss ',
      'yay -S ',
      'yay -Syu',

      // Homebrew
      'brew install ',
      'brew update',
      'brew upgrade',
      'brew search ',
      'brew list',
      'brew uninstall ',
      'brew info ',
      'brew doctor',
      'brew cleanup',
      'brew services list',
      'brew services start ',
      'brew services stop ',
      'brew cask install ',

      // Snap/Flatpak
      'snap install ',
      'snap list',
      'snap remove ',
      'snap refresh',
      'flatpak install ',
      'flatpak list',
      'flatpak run ',
      'flatpak uninstall ',
      'flatpak update',

      // Systemd
      'systemctl status ',
      'systemctl start ',
      'systemctl stop ',
      'systemctl restart ',
      'systemctl reload ',
      'systemctl enable ',
      'systemctl disable ',
      'systemctl list-units',
      'systemctl list-unit-files',
      'systemctl daemon-reload',
      'systemctl --user ',
      'journalctl -xe',
      'journalctl -f',
      'journalctl -u ',
      'journalctl --since "1 hour ago"',

      // Processus
      'ps aux',
      'ps -ef',
      'htop',
      'top',
      'btop',
      'kill -9 ',
      'killall ',
      'pkill ',
      'pgrep ',
      'nice -n ',
      'renice ',
      'nohup ',
      'jobs',
      'fg',
      'bg',
      'disown',

      // Mémoire/Disque
      'free -h',
      'vmstat',
      'iostat',
      'iotop',
      'lsblk',
      'fdisk -l',
      'mount',
      'umount ',
      'lsof -i',
      'fuser ',

      // Utilisateurs
      'whoami',
      'id',
      'who',
      'w',
      'last',
      'passwd',
      'useradd ',
      'usermod ',
      'userdel ',
      'groupadd ',
      'groups',
      'newgrp ',

      // Système
      'uname -a',
      'hostname',
      'hostnamectl',
      'uptime',
      'date',
      'cal',
      'timedatectl',
      'dmesg | tail',
      'lscpu',
      'lsusb',
      'lspci',
      'lshw',
      'dmidecode',
      'reboot',
      'shutdown -h now',
      'poweroff',
      'history',
      'history | grep ',
      'alias',
      'unalias ',
      'export ',
      'env',
      'printenv',
      'which ',
      'whereis ',
      'type ',
      'man ',
      'info ',
      'help',

      // Cron
      'crontab -e',
      'crontab -l',

      // ══════════════════════════════════════════════════════════════════════
      // RÉSEAU
      // ══════════════════════════════════════════════════════════════════════
      'curl ',
      'curl -X GET ',
      'curl -X POST ',
      'curl -I ',
      'curl -s ',
      'curl -o ',
      'curl -O ',
      'curl -L ',
      'curl -H "Content-Type: application/json" ',
      'curl -d \'{}\' ',
      'wget ',
      'wget -O ',
      'http GET ',
      'http POST ',
      'ping ',
      'ping -c 4 ',
      'traceroute ',
      'tracepath ',
      'mtr ',
      'dig ',
      'dig +short ',
      'nslookup ',
      'host ',
      'whois ',
      'netstat -tulpn',
      'ss -tulpn',
      'ip addr',
      'ip route',
      'ip link',
      'ifconfig',
      'route -n',
      'arp -a',
      'nmap ',
      'nmap -sV ',
      'nmap -p ',
      'nc -zv ',
      'telnet ',
      'tcpdump -i any',
      'iptables -L',
      'ufw status',
      'ufw enable',
      'ufw disable',
      'ufw allow ',
      'ufw deny ',

      // SSH/SCP
      'ssh ',
      'ssh -i ',
      'ssh -p ',
      'ssh-keygen -t ed25519',
      'ssh-copy-id ',
      'ssh-add',
      'ssh-agent',
      'scp ',
      'scp -r ',
      'sftp ',

      // ══════════════════════════════════════════════════════════════════════
      // TMUX / SCREEN
      // ══════════════════════════════════════════════════════════════════════
      'tmux',
      'tmux new -s ',
      'tmux new-session -s ',
      'tmux attach -t ',
      'tmux ls',
      'tmux list-sessions',
      'tmux kill-session -t ',
      'tmux detach',
      'tmux rename-session ',
      'tmux source-file ~/.tmux.conf',
      'screen ',
      'screen -S ',
      'screen -r',
      'screen -ls',
      'screen -d',
      'screen -dr',

      // ══════════════════════════════════════════════════════════════════════
      // ÉDITEURS
      // ══════════════════════════════════════════════════════════════════════
      'vim ',
      'vi ',
      'nvim ',
      'nano ',
      'emacs ',
      'code .',
      'code -r ',
      'code --diff ',
      'subl .',
      'atom .',
      'gedit ',
      'micro ',
      'helix ',
      'hx ',
      'zed .',
      'cursor .',

      // ══════════════════════════════════════════════════════════════════════
      // FLUTTER / DART
      // ══════════════════════════════════════════════════════════════════════
      'flutter run',
      'flutter run -d ',
      'flutter pub get',
      'flutter pub upgrade',
      'flutter pub add ',
      'flutter pub remove ',
      'flutter pub outdated',
      'flutter build apk',
      'flutter build ios',
      'flutter build web',
      'flutter build linux',
      'flutter build macos',
      'flutter build windows',
      'flutter test',
      'flutter clean',
      'flutter analyze',
      'flutter doctor',
      'flutter create ',
      'flutter devices',
      'flutter emulators',
      'flutter upgrade',
      'flutter channel',
      'flutter config',
      'flutter gen-l10n',
      'dart run ',
      'dart format .',
      'dart analyze',
      'dart test',
      'dart compile exe ',
      'dart pub get',
      'dart fix --apply',
      'dart create ',
      'dart doc',

      // ══════════════════════════════════════════════════════════════════════
      // RUST
      // ══════════════════════════════════════════════════════════════════════
      'cargo build',
      'cargo build --release',
      'cargo run',
      'cargo run --release',
      'cargo test',
      'cargo check',
      'cargo clippy',
      'cargo fmt',
      'cargo add ',
      'cargo new ',
      'cargo init',
      'cargo doc',
      'cargo doc --open',
      'cargo update',
      'cargo publish',
      'cargo clean',
      'cargo bench',
      'cargo tree',
      'cargo install ',
      'cargo uninstall ',
      'cargo search ',
      'cargo watch -x run',
      'rustc ',
      'rustc --version',
      'rustup update',
      'rustup default stable',
      'rustup target add ',
      'rustup component add ',
      'rustup show',

      // ══════════════════════════════════════════════════════════════════════
      // GO
      // ══════════════════════════════════════════════════════════════════════
      'go build',
      'go build -o ',
      'go run .',
      'go test ./...',
      'go test -v ./...',
      'go mod tidy',
      'go mod init ',
      'go mod download',
      'go mod vendor',
      'go get ',
      'go get -u ',
      'go fmt ./...',
      'go vet ./...',
      'go install ',
      'go clean',
      'go doc ',
      'go env',
      'go version',
      'go generate ./...',
      'go work ',
      'golangci-lint run',

      // ══════════════════════════════════════════════════════════════════════
      // JAVA / JVM
      // ══════════════════════════════════════════════════════════════════════
      'java ',
      'java -jar ',
      'java -version',
      'javac ',
      'mvn clean install',
      'mvn clean install -DskipTests',
      'mvn package',
      'mvn test',
      'mvn verify',
      'mvn dependency:tree',
      'mvn spring-boot:run',
      'gradle build',
      'gradle clean',
      'gradle clean build',
      'gradle test',
      'gradle run',
      'gradle tasks',
      'gradle --version',
      './gradlew build',
      './gradlew clean',
      './gradlew clean build',
      './gradlew test',

      // ══════════════════════════════════════════════════════════════════════
      // RUBY
      // ══════════════════════════════════════════════════════════════════════
      'ruby ',
      'ruby -v',
      'gem install ',
      'gem list',
      'gem uninstall ',
      'bundle install',
      'bundle exec ',
      'bundle update',
      'bundle add ',
      'rails server',
      'rails console',
      'rails generate ',
      'rails db:migrate',
      'rails new ',
      'rails routes',
      'rails test',
      'rake db:migrate',
      'rspec',
      'rspec -f d',
      'rubocop',
      'rubocop -a',

      // ══════════════════════════════════════════════════════════════════════
      // PHP
      // ══════════════════════════════════════════════════════════════════════
      'php ',
      'php -v',
      'php -S localhost:8000',
      'php artisan serve',
      'php artisan migrate',
      'php artisan make:controller ',
      'php artisan make:model ',
      'php artisan tinker',
      'php artisan route:list',
      'php artisan cache:clear',
      'php artisan config:clear',
      'php artisan queue:work',
      'composer install',
      'composer update',
      'composer require ',
      'composer dump-autoload',
      'composer create-project ',

      // ══════════════════════════════════════════════════════════════════════
      // BASES DE DONNÉES
      // ══════════════════════════════════════════════════════════════════════
      'mysql -u root -p',
      'mysqldump -u root -p ',
      'psql ',
      'psql -U postgres',
      'pg_dump ',
      'pg_restore ',
      'createdb ',
      'dropdb ',
      'sqlite3 ',
      'mongo',
      'mongosh',
      'mongod',
      'mongodump',
      'mongorestore',
      'redis-cli',
      'redis-cli ping',
      'redis-server',

      // ══════════════════════════════════════════════════════════════════════
      // MAKE / BUILD
      // ══════════════════════════════════════════════════════════════════════
      'make',
      'make clean',
      'make install',
      'make test',
      'make all',
      'make -j',
      'cmake .',
      'cmake -B build',
      'cmake --build build',
      'ninja',
      'ninja -C build',
      'meson setup build',

      // ══════════════════════════════════════════════════════════════════════
      // OUTILS CLI MODERNES
      // ══════════════════════════════════════════════════════════════════════
      'bat ',
      'bat -l ',
      'exa -la',
      'eza -la',
      'jq \'.\' ',
      'yq ',
      'https GET ',
      'lazygit',
      'lg',
      'tig',
      'ncdu',
      'tldr ',
      'neofetch',
      'fastfetch',
      'watchexec ',
      'hyperfine ',
      'tokei',
      'cloc .',

      // ══════════════════════════════════════════════════════════════════════
      // VERCEL / NETLIFY / HEROKU
      // ══════════════════════════════════════════════════════════════════════
      'vercel',
      'vercel dev',
      'vercel --prod',
      'vercel login',
      'vercel env pull',
      'netlify dev',
      'netlify deploy',
      'netlify deploy --prod',
      'netlify login',
      'heroku login',
      'heroku create',
      'heroku logs --tail',
      'heroku ps',
      'heroku run ',
      'heroku config',
      'heroku addons',

      // Serverless
      'serverless deploy',
      'sls deploy',
      'sls invoke local -f ',
      'sls offline',
      'sam build',
      'sam deploy',
      'sam local invoke ',
      'sam local start-api',
      'wrangler dev',
      'wrangler deploy',
      'wrangler login',
      'wrangler publish',

      // ══════════════════════════════════════════════════════════════════════
      // TESTING
      // ══════════════════════════════════════════════════════════════════════
      'jest',
      'jest --watch',
      'jest --coverage',
      'vitest',
      'vitest run',
      'vitest watch',
      'vitest --coverage',
      'playwright test',
      'playwright test --ui',
      'playwright codegen',
      'playwright show-report',
      'cypress open',
      'cypress run',
    ];

    // Trouver la première commande qui commence par l'input
    for (final cmd in commands) {
      if (cmd.toLowerCase().startsWith(lower) && cmd.length > input.length) {
        // Retourner le reste de la commande
        return cmd.substring(input.length);
      }
    }

    return null;
  }
}

final terminalProvider = StateNotifierProvider<TerminalNotifier, TerminalState>(
  (ref) => TerminalNotifier(),
);

/// Provider pour tracker si le terminal a été scrollé vers le haut
/// (pour afficher le bouton "scroll to bottom")
final terminalScrolledUpProvider = StateProvider<bool>((ref) => false);

/// Provider pour le mode édition (nano, vim, less, htop, etc.)
/// True quand une app utilise l'alternate screen mode
final isEditorModeProvider = StateProvider<bool>((ref) => false);

