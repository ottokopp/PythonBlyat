import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart' as s;
import 'package:flutter/widgets.dart' as fw;
import 'package:highlight/languages/python.dart' as python_language;

enum _BackgroundTrack { none, world, boss }

fw.Widget _buildQuestionPrompt(String prompt) {
	return m.Container(
		width: double.infinity,
		padding: const m.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
		decoration: m.BoxDecoration(
			color: const m.Color(0xFFFFFFFF),
			borderRadius: m.BorderRadius.circular(10),
			border: m.Border.all(color: const m.Color(0xFFD6DCE6)),
		),
		child: m.Text(
			prompt,
			style: const m.TextStyle(
				fontSize: 18,
				fontWeight: m.FontWeight.w600,
				color: m.Color(0xFF111111),
			),
		),
	);
}

void main() {
	fw.runApp(const MainPageHost());
}

class User {
	User({
		required this.assigned_cards,
		required this.achievements,
		required this.name,
	});

	final List<Card> assigned_cards;
	final List<String> achievements;
	final String name;
}

class Card {
	Card({
		required this.last_review,
		required this.due,
	});

	final DateTime last_review;
	final DateTime due;
}

class CodeCard extends Card {
	CodeCard({
		required super.last_review,
		required super.due,
		required this.worldNumber,
		required this.levelNumber,
		required this.cardNumber,
		required this.prompt,
		required this.starterCode,
		required this.expectedCode,
	});

	final int worldNumber;
	final int levelNumber;
	final int cardNumber;
	final String prompt;
	final String starterCode;
	final String expectedCode;
}

class MultipleChoiceCard extends Card {
	MultipleChoiceCard({
		required super.last_review,
		required super.due,
		required this.worldNumber,
		required this.levelNumber,
		required this.cardNumber,
		required this.prompt,
		required this.options,
		required this.correctOption,
	});

	final int worldNumber;
	final int levelNumber;
	final int cardNumber;
	final String prompt;
	final List<String> options;
	final String correctOption;
}

class ClozeCard extends Card {
	ClozeCard({
		required super.last_review,
		required super.due,
		required this.worldNumber,
		required this.levelNumber,
		required this.cardNumber,
		required this.prompt,
		required this.solutions,
	});

	final int worldNumber;
	final int levelNumber;
	final int cardNumber;
	final String prompt;
	final List<String> solutions;
}

int _cardWorldNumber(Card card) {
	if (card is CodeCard) {
		return card.worldNumber;
	}
	if (card is MultipleChoiceCard) {
		return card.worldNumber;
	}
	if (card is ClozeCard) {
		return card.worldNumber;
	}
	return 0;
}

int _cardLevelNumber(Card card) {
	if (card is CodeCard) {
		return card.levelNumber;
	}
	if (card is MultipleChoiceCard) {
		return card.levelNumber;
	}
	if (card is ClozeCard) {
		return card.levelNumber;
	}
	return 0;
}

int _cardNumber(Card card) {
	if (card is CodeCard) {
		return card.cardNumber;
	}
	if (card is MultipleChoiceCard) {
		return card.cardNumber;
	}
	if (card is ClozeCard) {
		return card.cardNumber;
	}
	return 0;
}

bool _isEnabledQuestionCard(int worldNumber, int levelNumber, int cardNumber) {
	return true;
}

String _decodeCardEscapes(String value) {
	return value
		.replaceAll(r'\n', '\n')
		.replaceAll(r'\t', '\t')
		.replaceAll(r'\r', '\r');
}

List<String> _extractPipeValues(String input, {bool trimValues = true}) {
	final String flattened = input.replaceAll(RegExp(r'\r?\n'), '');
	final List<String> values = flattened
		.split('|')
		.where((String segment) => segment.isNotEmpty)
		.toList();
	if (!trimValues) {
		return values;
	}
	return values
		.map((String value) => value.trim())
		.where((String value) => value.isNotEmpty)
		.toList();
}

List<Card> parseQuestionCardsFromText(String raw) {
	final RegExp startPattern = RegExp(
		r'^(\d+)\.(\d+)\.(\d+)\s+@([A-Za-z]+);(.*)$',
	);
	final List<String> lines = raw.split(RegExp(r'\r?\n'));
	final List<Card> cards = <Card>[];

	for (int i = 0; i < lines.length; i++) {
		final String line = lines[i].trim();
		final RegExpMatch? match = startPattern.firstMatch(line);
		if (match == null) {
			continue;
		}

		final int worldNumber = int.parse(match.group(1)!);
		final int levelNumber = int.parse(match.group(2)!);
		final int cardNumber = int.parse(match.group(3)!);
		if (!_isEnabledQuestionCard(worldNumber, levelNumber, cardNumber)) {
			continue;
		}

		final String type = match.group(4)!.toLowerCase();
		String payload = match.group(5)!;
		while (!payload.contains('@') && i + 1 < lines.length) {
			i++;
			payload = '$payload\n${lines[i]}';
		}

		final int payloadEnd = payload.indexOf('@');
		if (payloadEnd == -1) {
			continue;
		}
		payload = payload.substring(0, payloadEnd);

		final int questionEnd = payload.indexOf(';');
		if (questionEnd == -1) {
			continue;
		}

		final String question = _decodeCardEscapes(
			payload.substring(0, questionEnd).trim(),
		);
		final String body = payload.substring(questionEnd + 1);
		final DateTime now = DateTime.now();

		if (type == 'multiple') {
			final List<String> options = _extractPipeValues(body);
			if (options.length < 4) {
				continue;
			}
			final List<String> decodedOptions = options
				.take(4)
				.map(_decodeCardEscapes)
				.toList();
			cards.add(
				MultipleChoiceCard(
					last_review: now,
					due: now,
					worldNumber: worldNumber,
					levelNumber: levelNumber,
					cardNumber: cardNumber,
					prompt: question,
					options: decodedOptions,
					correctOption: decodedOptions.first,
				),
			);
			continue;
		}

		if (type == 'code') {
			final List<String> values = _extractPipeValues(body, trimValues: false);
			if (values.length < 2) {
				continue;
			}
			cards.add(
				CodeCard(
					last_review: now,
					due: now,
					worldNumber: worldNumber,
					levelNumber: levelNumber,
					cardNumber: cardNumber,
					prompt: question,
					starterCode: _decodeCardEscapes(values[0].trim()),
					expectedCode: _decodeCardEscapes(values[1].trim()),
				),
			);
			continue;
		}

		if (type == 'cloze') {
			final List<String> solutions = _extractPipeValues(body)
				.map(_decodeCardEscapes)
				.toList();
			if (solutions.isEmpty) {
				continue;
			}
			cards.add(
				ClozeCard(
					last_review: now,
					due: now,
					worldNumber: worldNumber,
					levelNumber: levelNumber,
					cardNumber: cardNumber,
					prompt: question,
					solutions: solutions,
				),
			);
		}
	}

	cards.sort((Card a, Card b) {
		final int worldDiff = _cardWorldNumber(a).compareTo(_cardWorldNumber(b));
		if (worldDiff != 0) {
			return worldDiff;
		}
		final int levelDiff = _cardLevelNumber(a).compareTo(_cardLevelNumber(b));
		if (levelDiff != 0) {
			return levelDiff;
		}
		return _cardNumber(a).compareTo(_cardNumber(b));
	});

	return cards;
}

class Level {
	Level({this.completed = true});

	bool completed;
}

typedef LevelNode = Node;

class Node {
	Node({
		required this.id,
		required this.level,
		required this.row,
		required this.col,
		this.isSecret = false,
		this.revealConditionMet = false,
	});

	final String id;
	final Level level;
	final List<Node> targets = <Node>[];
	final List<Node> parents = <Node>[];
	final int row;
	final int col;
	final bool isSecret;
	bool revealConditionMet;
}

class EdgeLink {
	const EdgeLink({
		required this.from,
		required this.to,
		required this.hidden,
	});

	final String from;
	final String to;
	final bool hidden;
}

class WorldMapData {
	WorldMapData({
		required this.worldNumber,
		required this.title,
		required this.requiredAchievement,
		required this.nodesById,
		required this.edges,
	});

	final int worldNumber;
	final String title;
	final String? requiredAchievement;
	final Map<String, Node> nodesById;
	final List<EdgeLink> edges;

	List<Node> get numericNodesInOrder {
		final List<Node> numeric = nodesById.values
			.where((Node n) => int.tryParse(n.id) != null)
			.toList();
		numeric.sort(
			(Node a, Node b) => int.parse(a.id).compareTo(int.parse(b.id)),
		);
		return numeric;
	}

	Node? get secretNode => nodesById['X'];

	Node? get level8Node => nodesById['8'];

	static WorldMapData parse({
		required int worldNumber,
		required String raw,
		required String? requiredAchievement,
	}) {
		final List<String> rawLines = raw.split(RegExp(r'\r?\n'));
		final Map<String, Node> nodesById = <String, Node>{};
		for (int row = 0; row < 16; row++) {
			final String line = row < rawLines.length ? rawLines[row] : '';
			final String padded = line.padRight(16, '#');
			for (int col = 0; col < 16; col++) {
				final String symbol = padded[col];
				if (symbol == '#') {
					continue;
				}

				if (RegExp(r'[0-9X]').hasMatch(symbol)) {
					nodesById[symbol] = Node(
						id: symbol,
						level: Level(completed: false),
						row: row,
						col: col,
						isSecret: symbol == 'X',
					);
				}
			}
		}

		final List<String> edgeLines = rawLines
			.skip(16)
			.map((String l) => l.trim())
			.where((String l) => l.isNotEmpty)
			.toList();

		final RegExp edgePattern = RegExp(r'^([0-9X])(->|=>)([0-9X])$');
		final List<EdgeLink> edges = <EdgeLink>[];
		for (final String line in edgeLines) {
			final RegExpMatch? match = edgePattern.firstMatch(line);
			if (match == null) {
				continue;
			}

			final String from = match.group(1)!;
			final String arrow = match.group(2)!;
			final String to = match.group(3)!;
			final Node? fromNode = nodesById[from];
			final Node? toNode = nodesById[to];
			if (fromNode == null || toNode == null) {
				continue;
			}

			fromNode.targets.add(toNode);
			toNode.parents.add(fromNode);
			edges.add(EdgeLink(from: from, to: to, hidden: arrow == '=>'));
		}

		return WorldMapData(
			worldNumber: worldNumber,
			title: 'World $worldNumber',
			requiredAchievement: requiredAchievement,
			nodesById: nodesById,
			edges: edges,
		);
	}
}

abstract class Page extends fw.StatelessWidget {
	const Page({super.key});
}

class WorldPage extends Page {
	const WorldPage({
		super.key,
		required this.levelNodes,
		required this.onBack,
		required this.getWorlds,
		required this.getWorldLayoutRevision,
		required this.getSelectedWorldIndex,
		required this.getActiveLearnLevel,
		required this.getLearnWindowCards,
		required this.getLearnCardsLoading,
		required this.isWorldUnlocked,
		required this.selectWorld,
		required this.isSecretRevealConditionMet,
		required this.isBossLevel,
		required this.onLevelNodeTap,
		required this.onCloseLearnWindow,
		required this.onAnswerCorrect,
		required this.onAnswerWrong,
		required this.onLearnLevelCompleted,
		required this.onDebugUnlockNextLevel,
		required this.onDebugUnlockSecretLevel,
	});

	final List<LevelNode> levelNodes;
	final fw.VoidCallback onBack;
	final List<WorldMapData> Function() getWorlds;
	final int Function() getWorldLayoutRevision;
	final int Function() getSelectedWorldIndex;
	final int? Function() getActiveLearnLevel;
	final List<Card> Function() getLearnWindowCards;
	final bool Function() getLearnCardsLoading;
	final bool Function(int worldIndex) isWorldUnlocked;
	final void Function(int worldIndex) selectWorld;
	final bool Function(int worldIndex) isSecretRevealConditionMet;
	final bool Function(int worldNumber, int levelNumber) isBossLevel;
	final void Function(int worldNumber, int levelNumber) onLevelNodeTap;
	final fw.VoidCallback onCloseLearnWindow;
	final fw.VoidCallback onAnswerCorrect;
	final fw.VoidCallback onAnswerWrong;
	final void Function(int levelNumber) onLearnLevelCompleted;
	final fw.VoidCallback onDebugUnlockNextLevel;
	final fw.VoidCallback onDebugUnlockSecretLevel;

	@override
	fw.Widget build(fw.BuildContext context) {
		final List<WorldMapData> worlds = getWorlds();
		if (worlds.isEmpty) {
			return _PageShell(
				onBack: onBack,
				child: const m.Text('Loading worlds...'),
			);
		}

		final int selectedWorldIndex = getSelectedWorldIndex();
		final int worldLayoutRevision = getWorldLayoutRevision();
		final int? activeLearnLevel = getActiveLearnLevel();
		final List<Card> learnWindowCards = getLearnWindowCards();
		final bool learnCardsLoading = getLearnCardsLoading();
		final WorldMapData selectedWorld = worlds[selectedWorldIndex];
		final bool revealConditionMet =
			isSecretRevealConditionMet(selectedWorldIndex);
		final bool showBossWindow =
			activeLearnLevel != null &&
			isBossLevel(selectedWorld.worldNumber, activeLearnLevel);

		return _PageShell(
			onBack: onBack,
			rightAction: m.Wrap(
				spacing: 8,
				children: <fw.Widget>[
					m.FilledButton.tonal(
						onPressed: onDebugUnlockSecretLevel,
						child: const m.Text('DEBUG Unlock secret level'),
					),
					m.FilledButton.tonal(
						onPressed: onDebugUnlockNextLevel,
						child: const m.Text('DEBUG Unlock next level'),
					),
				],
			),
			centerChild: false,
			child: m.Stack(
				children: <fw.Widget>[
					m.Column(
						crossAxisAlignment: m.CrossAxisAlignment.start,
						children: <fw.Widget>[
							m.SingleChildScrollView(
								scrollDirection: m.Axis.horizontal,
								child: m.Row(
									children: List<fw.Widget>.generate(worlds.length, (
										int index,
									) {
										final bool unlocked = isWorldUnlocked(index);
										return m.Padding(
											padding: const m.EdgeInsets.only(right: 8),
											child: m.ElevatedButton(
												onPressed: unlocked
													? () => selectWorld(index)
													: null,
												style: m.ElevatedButton.styleFrom(
													backgroundColor: selectedWorldIndex == index
														? const m.Color(0xFF3F7CFF)
														: null,
												),
												child: m.Text(
													unlocked
														? worlds[index].title
														: '${worlds[index].title} (Locked)',
												),
											),
										);
									}),
								),
							),
							const m.SizedBox(height: 10),
							m.Expanded(
								child: WorldGrid(
									world: selectedWorld,
									revealConditionMet: revealConditionMet,
									layoutRevision: worldLayoutRevision,
									onLevelTap: (Node node, bool unlocked) {
										if (!unlocked) {
											return;
										}
										final int? levelNumber = int.tryParse(node.id);
										if (levelNumber == null) {
											return;
										}
										onLevelNodeTap(selectedWorld.worldNumber, levelNumber);
									},
								),
							),
						],
					),
					if (activeLearnLevel != null)
						m.Positioned.fill(
							child: m.Container(
								color: const m.Color(0x88000000),
								child: showBossWindow
									? BossWindow(
										worldNumber: selectedWorld.worldNumber,
										levelNumber: activeLearnLevel,
										cards: learnWindowCards,
										loading: learnCardsLoading,
										onClose: onCloseLearnWindow,
										onLevelCompleted: () => onLearnLevelCompleted(
											activeLearnLevel,
										),
										onAnswerCorrect: onAnswerCorrect,
										onAnswerWrong: onAnswerWrong,
									)
									: LearnWindow(
										worldNumber: selectedWorld.worldNumber,
										levelNumber: activeLearnLevel,
										cards: learnWindowCards,
										loading: learnCardsLoading,
										onClose: onCloseLearnWindow,
										onLevelCompleted: () => onLearnLevelCompleted(
											activeLearnLevel,
										),
										onAnswerCorrect: onAnswerCorrect,
										onAnswerWrong: onAnswerWrong,
									),
							),
						),
				],
			),
		);
	}
}

class LearnPage extends Page {
	const LearnPage({
		super.key,
		required this.onBack,
		required this.onAnswerCorrect,
		required this.onAnswerWrong,
		required this.onLevelWon,
	});

	final fw.VoidCallback onBack;
	final fw.VoidCallback onAnswerCorrect;
	final fw.VoidCallback onAnswerWrong;
	final fw.VoidCallback onLevelWon;

	@override
	fw.Widget build(fw.BuildContext context) {
		return _PageShell(
			onBack: onBack,
			centerChild: false,
			child: LearnLevelRunner(
				onAnswerCorrect: onAnswerCorrect,
				onAnswerWrong: onAnswerWrong,
				onLevelWon: onLevelWon,
			),
		);
	}
}

class LearnLevelRunner extends fw.StatefulWidget {
	const LearnLevelRunner({
		super.key,
		required this.onAnswerCorrect,
		required this.onAnswerWrong,
		required this.onLevelWon,
	});

	final fw.VoidCallback onAnswerCorrect;
	final fw.VoidCallback onAnswerWrong;
	final fw.VoidCallback onLevelWon;

	@override
	fw.State<LearnLevelRunner> createState() => _LearnLevelRunnerState();
}

class _LearnLevelRunnerState extends fw.State<LearnLevelRunner> {
	Map<int, List<Card>> _cardsByLevel = <int, List<Card>>{};
	bool _loading = true;
	String? _error;
	int _selectedLevel = 1;
	int _cardIndex = 0;
	int _attemptRevision = 0;
	String? _status;

	List<int> get _levels {
		final List<int> levels = _cardsByLevel.keys.toList()..sort();
		return levels;
	}

	List<Card> get _currentLevelCards =>
		_cardsByLevel[_selectedLevel] ?? const <Card>[];

	Card? get _currentCard {
		if (_cardIndex < 0 || _cardIndex >= _currentLevelCards.length) {
			return null;
		}
		return _currentLevelCards[_cardIndex];
	}

	@override
	void initState() {
		super.initState();
		_loadCards();
	}

	Future<void> _loadCards() async {
		try {
			final String raw = await s.rootBundle.loadString('assets/fragen_welt.txt');
			final List<Card> parsed = parseQuestionCardsFromText(raw)
				.where((Card card) => _cardWorldNumber(card) == 1)
				.toList();

			final Map<int, List<Card>> grouped = <int, List<Card>>{};
			for (final Card card in parsed) {
				final int level = _cardLevelNumber(card);
				grouped.putIfAbsent(level, () => <Card>[]).add(card);
			}

			if (!mounted) {
				return;
			}

			setState(() {
				_cardsByLevel = grouped;
				_loading = false;
				_error = null;
				if (_levels.isNotEmpty) {
					_selectedLevel = _levels.first;
				}
				_cardIndex = 0;
			});
		} catch (error) {
			if (!mounted) {
				return;
			}
			setState(() {
				_loading = false;
				_error = '$error';
			});
		}
	}

	void _selectLevel(int level) {
		setState(() {
			_selectedLevel = level;
			_cardIndex = 0;
			_attemptRevision++;
			_status = null;
		});
	}

	void _resetLevelWithFailure() {
		setState(() {
			_cardIndex = 0;
			_attemptRevision++;
			_status = 'Falsch. Das Level wurde auf den Anfang zurückgesetzt.';
		});
	}

	bool _proceedToNextCard() {
		setState(() {
			if (_cardIndex + 1 < _currentLevelCards.length) {
				_cardIndex++;
				_status = null;
				return;
			}
			_cardIndex = _currentLevelCards.length;
			_status = 'Level $_selectedLevel abgeschlossen.';
		});
		return _cardIndex >= _currentLevelCards.length;
	}

	void _handleCardResult(bool correct) {
		if (correct) {
			widget.onAnswerCorrect();
			final bool levelWon = _proceedToNextCard();
			if (levelWon) {
				widget.onLevelWon();
			}
			return;
		}
		widget.onAnswerWrong();
		_resetLevelWithFailure();
	}

	fw.Widget _buildCard(Card card) {
		if (card is MultipleChoiceCard) {
			return _MultipleChoiceCardView(
				key: fw.ValueKey<String>(
					'mc-${card.levelNumber}-${card.cardNumber}-$_attemptRevision-$_cardIndex',
				),
				card: card,
				onAnswered: _handleCardResult,
			);
		}

		if (card is CodeCard) {
			return _CodeCardView(
				key: fw.ValueKey<String>(
					'code-${card.levelNumber}-${card.cardNumber}-$_attemptRevision-$_cardIndex',
				),
				card: card,
				onSolved: _handleCardResult,
			);
		}

		if (card is ClozeCard) {
			return ClozeWidget(
				key: fw.ValueKey<String>(
					'cloze-${card.levelNumber}-${card.cardNumber}-$_attemptRevision-$_cardIndex',
				),
				card: card,
				onSolved: _handleCardResult,
			);
		}

		return const m.Text('Unbekannter Kartentyp.');
	}

	@override
	fw.Widget build(fw.BuildContext context) {
		if (_loading) {
			return const m.Center(child: m.CircularProgressIndicator());
		}

		if (_error != null) {
			return m.Text('Fehler beim Laden der Fragen: $_error');
		}

		if (_levels.isEmpty) {
			return const m.Text('Keine Karten gefunden.');
		}

		final List<Card> cardsInLevel = _currentLevelCards;
		final Card? currentCard = _currentCard;

		return m.Column(
			crossAxisAlignment: m.CrossAxisAlignment.start,
			children: <fw.Widget>[
				const m.Text(
					'Learn Mode - World 1',
					style: m.TextStyle(fontSize: 20, fontWeight: m.FontWeight.w700),
				),
				const m.SizedBox(height: 10),
				m.Wrap(
					spacing: 8,
					children: _levels.map((int level) {
						return m.ChoiceChip(
							label: m.Text('Level 1.$level'),
							selected: _selectedLevel == level,
							onSelected: (_) => _selectLevel(level),
						);
					}).toList(),
				),
				const m.SizedBox(height: 12),
				m.Text(
					currentCard == null
						? 'Karten in Level 1.$_selectedLevel: ${cardsInLevel.length}'
						: 'Karte 1.$_selectedLevel.${_cardNumber(currentCard)}',
				),
				if (_status != null) ...<fw.Widget>[
					const m.SizedBox(height: 8),
					m.Text(
						_status!,
						style: m.TextStyle(
							color: _status!.startsWith('Falsch')
								? const m.Color(0xFFE74C3C)
								: const m.Color(0xFF2ECC71),
							fontWeight: m.FontWeight.w600,
						),
					),
				],
				const m.SizedBox(height: 12),
				m.Expanded(
					child: m.Container(
						padding: const m.EdgeInsets.all(12),
						decoration: m.BoxDecoration(
							borderRadius: m.BorderRadius.circular(12),
							color: const m.Color(0x11FFFFFF),
							border: m.Border.all(color: const m.Color(0x22FFFFFF)),
						),
						child: currentCard == null
							? const m.Center(child: m.Text('Level abgeschlossen.'))
							: _buildCard(currentCard),
					),
				),
			],
		);
	}
}

class _MultipleChoiceCardView extends fw.StatefulWidget {
	const _MultipleChoiceCardView({
		required super.key,
		required this.card,
		required this.onAnswered,
	});

	final MultipleChoiceCard card;
	final fw.ValueChanged<bool> onAnswered;

	@override
	fw.State<_MultipleChoiceCardView> createState() =>
		_MultipleChoiceCardViewState();
}

class _MultipleChoiceCardViewState extends fw.State<_MultipleChoiceCardView> {
	late final List<String> _shuffledOptions;

	@override
	void initState() {
		super.initState();
		_shuffledOptions = List<String>.from(widget.card.options)..shuffle();
	}

	@override
	fw.Widget build(fw.BuildContext context) {
		return m.Column(
			crossAxisAlignment: m.CrossAxisAlignment.start,
			children: <fw.Widget>[
				_buildQuestionPrompt(widget.card.prompt),
				const m.SizedBox(height: 12),
				..._shuffledOptions.map((String option) {
					return m.Padding(
						padding: const m.EdgeInsets.only(bottom: 8),
						child: m.SizedBox(
							width: double.infinity,
							child: m.ElevatedButton(
								onPressed: () => widget.onAnswered(
									option == widget.card.correctOption,
								),
								child: m.Text(option),
							),
						),
					);
				}),
			],
		);
	}
}

class _CodeCardView extends fw.StatefulWidget {
	const _CodeCardView({
		required super.key,
		required this.card,
		required this.onSolved,
	});

	final CodeCard card;
	final fw.ValueChanged<bool> onSolved;

	@override
	fw.State<_CodeCardView> createState() => _CodeCardViewState();
}

class _CodeCardViewState extends fw.State<_CodeCardView> {
	late String _currentCode;

	@override
	void initState() {
		super.initState();
		_currentCode = widget.card.starterCode;
	}

	String _normalizeCode(String value) {
		return value.replaceAll(RegExp(r'\s+'), '');
	}

	@override
	fw.Widget build(fw.BuildContext context) {
		return m.Column(
			crossAxisAlignment: m.CrossAxisAlignment.start,
			children: <fw.Widget>[
				_buildQuestionPrompt(widget.card.prompt),
				const m.SizedBox(height: 10),
				const m.Text('Startcode:'),
				const m.SizedBox(height: 6),
				m.Expanded(
					child: CodeEditWidget(
						initialCode: widget.card.starterCode,
						onChanged: (String value) {
							_currentCode = value;
						},
					),
				),
				const m.SizedBox(height: 10),
				m.Align(
					alignment: m.Alignment.centerRight,
					child: m.FilledButton(
						onPressed: () {
							final bool correct =
								_normalizeCode(_currentCode) ==
								_normalizeCode(widget.card.expectedCode);
							widget.onSolved(correct);
						},
						child: const m.Text('Lösen'),
					),
				),
			],
		);
	}
}

class ClozeWidget extends fw.StatefulWidget {
	const ClozeWidget({
		required super.key,
		required this.card,
		required this.onSolved,
	});

	final ClozeCard card;
	final fw.ValueChanged<bool> onSolved;

	@override
	fw.State<ClozeWidget> createState() => _ClozeWidgetState();
}

class _ClozeWidgetState extends fw.State<ClozeWidget> {
	late final List<m.TextEditingController> _controllers;

	@override
	void initState() {
		super.initState();
		_controllers = List<m.TextEditingController>.generate(
			widget.card.solutions.length,
			(_) => m.TextEditingController(),
		);
	}

	@override
	void dispose() {
		for (final m.TextEditingController controller in _controllers) {
			controller.dispose();
		}
		super.dispose();
	}

	List<String> _tokenize(String segment) {
		if (segment.trim().isEmpty) {
			return <String>[];
		}
		return segment
			.trim()
			.split(RegExp(r'\s+'))
			.where((String token) => token.isNotEmpty)
			.toList();
	}

	bool _checkSolutions() {
		for (int i = 0; i < widget.card.solutions.length; i++) {
			if (_controllers[i].text.trim() != widget.card.solutions[i].trim()) {
				return false;
			}
		}
		return true;
	}

	@override
	fw.Widget build(fw.BuildContext context) {
		final List<String> segments = widget.card.prompt.split(RegExp(r'_{3,}'));

		final List<fw.Widget> flowItems = <fw.Widget>[];
		for (int i = 0; i < segments.length; i++) {
			for (final String token in _tokenize(segments[i])) {
				flowItems.add(
					m.Padding(
						padding: const m.EdgeInsets.only(right: 5, bottom: 8),
						child: m.Text(token),
					),
				);
			}

			if (i < widget.card.solutions.length) {
				final double width =
					56 + (i % 3) * 16 + (widget.card.solutions[i].length * 7);
				flowItems.add(
					m.Padding(
						padding: const m.EdgeInsets.only(right: 5, bottom: 8),
						child: m.SizedBox(
							width: width,
							child: m.TextField(
								controller: _controllers[i],
								decoration: const m.InputDecoration(
									isDense: true,
									border: m.OutlineInputBorder(),
								),
							),
						),
					),
				);
			}
		}

		return m.Column(
			crossAxisAlignment: m.CrossAxisAlignment.start,
			children: <fw.Widget>[
				_buildQuestionPrompt(widget.card.prompt),
				const m.SizedBox(height: 10),
				m.Wrap(children: flowItems),
				const m.SizedBox(height: 10),
				m.Align(
					alignment: m.Alignment.centerRight,
					child: m.FilledButton(
						onPressed: () => widget.onSolved(_checkSolutions()),
						child: const m.Text('Lösen'),
					),
				),
			],
		);
	}
}

class LearnWindow extends fw.StatefulWidget {
	const LearnWindow({
		super.key,
		required this.worldNumber,
		required this.levelNumber,
		required this.cards,
		required this.loading,
		required this.onClose,
		required this.onAnswerCorrect,
		required this.onAnswerWrong,
		required this.onLevelCompleted,
	});

	final int worldNumber;
	final int levelNumber;
	final List<Card> cards;
	final bool loading;
	final fw.VoidCallback onClose;
	final fw.VoidCallback onAnswerCorrect;
	final fw.VoidCallback onAnswerWrong;
	final fw.VoidCallback onLevelCompleted;

	@override
	fw.State<LearnWindow> createState() => _LearnWindowState();
}

class _LearnWindowState extends fw.State<LearnWindow> {
	int _cardIndex = 0;
	int _attemptRevision = 0;
	String? _status;

	Card? get _currentCard {
		if (_cardIndex < 0 || _cardIndex >= widget.cards.length) {
			return null;
		}
		return widget.cards[_cardIndex];
	}

	@override
	void didUpdateWidget(covariant LearnWindow oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.levelNumber != widget.levelNumber ||
			oldWidget.worldNumber != widget.worldNumber) {
			setState(() {
				_cardIndex = 0;
				_attemptRevision = 0;
				_status = null;
			});
		}
	}

	void _resetLevelWithFailure() {
		setState(() {
			_cardIndex = 0;
			_attemptRevision++;
			_status = 'Falsch. Das Level wurde auf den Anfang zurückgesetzt.';
		});
	}

	void _handleCardResult(bool correct) {
		if (!correct) {
			widget.onAnswerWrong();
			_resetLevelWithFailure();
			return;
		}

		widget.onAnswerCorrect();

		if (_cardIndex + 1 < widget.cards.length) {
			setState(() {
				_cardIndex++;
				_status = null;
			});
			return;
		}

		widget.onLevelCompleted();
	}

	fw.Widget _buildCard(Card card) {
		if (card is MultipleChoiceCard) {
			return _MultipleChoiceCardView(
				key: fw.ValueKey<String>(
					'window-mc-${card.levelNumber}-${card.cardNumber}-$_attemptRevision-$_cardIndex',
				),
				card: card,
				onAnswered: _handleCardResult,
			);
		}

		if (card is CodeCard) {
			return _CodeCardView(
				key: fw.ValueKey<String>(
					'window-code-${card.levelNumber}-${card.cardNumber}-$_attemptRevision-$_cardIndex',
				),
				card: card,
				onSolved: _handleCardResult,
			);
		}

		if (card is ClozeCard) {
			return ClozeWidget(
				key: fw.ValueKey<String>(
					'window-cloze-${card.levelNumber}-${card.cardNumber}-$_attemptRevision-$_cardIndex',
				),
				card: card,
				onSolved: _handleCardResult,
			);
		}

		return const m.Text('Unbekannter Kartentyp.');
	}

	@override
	fw.Widget build(fw.BuildContext context) {
		return m.Center(
			child: m.ConstrainedBox(
				constraints: const m.BoxConstraints(maxWidth: 900, maxHeight: 680),
				child: m.Material(
					color: const m.Color(0xFF121A24),
					borderRadius: m.BorderRadius.circular(14),
					child: m.Padding(
						padding: const m.EdgeInsets.all(14),
						child: m.Column(
							crossAxisAlignment: m.CrossAxisAlignment.start,
							children: <fw.Widget>[
								m.Row(
									children: <fw.Widget>[
										m.Text(
											'LearnWindow - World ${widget.worldNumber}, Level ${widget.levelNumber}',
											style: const m.TextStyle(
												fontSize: 18,
												fontWeight: m.FontWeight.w700,
											),
										),
										const m.Spacer(),
										m.IconButton(
											onPressed: widget.onClose,
											icon: const m.Icon(m.Icons.close),
										),
									],
								),
								const m.SizedBox(height: 6),
								if (_status != null)
									m.Text(
										_status!,
										style: const m.TextStyle(
											color: m.Color(0xFFE74C3C),
											fontWeight: m.FontWeight.w600,
										),
									),
								if (_currentCard != null)
									m.Text(
										'Karte ${_cardIndex + 1} / ${widget.cards.length}',
									),
								const m.SizedBox(height: 10),
								m.Expanded(
									child: m.Container(
										padding: const m.EdgeInsets.all(12),
										decoration: m.BoxDecoration(
											borderRadius: m.BorderRadius.circular(12),
											color: const m.Color(0x11FFFFFF),
											border: m.Border.all(
												color: const m.Color(0x22FFFFFF),
											),
										),
										child: widget.loading
											? const m.Center(
													child: m.CircularProgressIndicator(),
												)
											: (widget.cards.isEmpty
													? const m.Center(
															child: m.Text(
																'Für dieses Level sind noch keine Karten vorhanden.',
															),
														)
													: (_currentCard == null
															? const m.Center(
																	child: m.Text('Level abgeschlossen.'),
																)
															: _buildCard(_currentCard!))),
									),
								),
							],
						),
					),
				),
			),
		);
	}
}

class BossWindow extends fw.StatefulWidget {
	const BossWindow({
		super.key,
		required this.worldNumber,
		required this.levelNumber,
		required this.cards,
		required this.loading,
		required this.onClose,
		required this.onAnswerCorrect,
		required this.onAnswerWrong,
		required this.onLevelCompleted,
	});

	final int worldNumber;
	final int levelNumber;
	final List<Card> cards;
	final bool loading;
	final fw.VoidCallback onClose;
	final fw.VoidCallback onAnswerCorrect;
	final fw.VoidCallback onAnswerWrong;
	final fw.VoidCallback onLevelCompleted;

	@override
	fw.State<BossWindow> createState() => _BossWindowState();
}

class _BossWindowState extends fw.State<BossWindow> {
	static const int _bossMaxHp = 20;
	static const int _playerMaxHp = 8;

	int _bossHp = _bossMaxHp;
	int _playerHp = _playerMaxHp;
	int _cardIndex = 0;
	int _attemptRevision = 0;
	String? _combatText;
	m.Color _combatTextColor = const m.Color(0xFFE8ECF2);
	DateTime _cardShownAt = DateTime.now();

	Card? get _currentCard {
		if (widget.cards.isEmpty) {
			return null;
		}
		final int normalized = _cardIndex % widget.cards.length;
		return widget.cards[normalized];
	}

	int get _displayCardIndex {
		if (widget.cards.isEmpty) {
			return 0;
		}
		return (_cardIndex % widget.cards.length) + 1;
	}

	bool get _won => _bossHp <= 0;

	bool get _lost => _playerHp <= 0;

	@override
	void initState() {
		super.initState();
		_resetTimer();
	}

	@override
	void didUpdateWidget(covariant BossWindow oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.levelNumber != widget.levelNumber ||
			oldWidget.worldNumber != widget.worldNumber) {
			setState(() {
				_resetFightState();
			});
		}
	}

	void _resetFightState() {
		_bossHp = _bossMaxHp;
		_playerHp = _playerMaxHp;
		_cardIndex = 0;
		_attemptRevision = 0;
		_combatText = null;
		_combatTextColor = const m.Color(0xFFE8ECF2);
		_resetTimer();
	}

	void _resetTimer() {
		_cardShownAt = DateTime.now();
	}

	int _damageFromSpeed(Duration elapsed) {
		final int ms = elapsed.inMilliseconds;
		if (ms < 3000) {
			return 6;
		}
		if (ms < 10000) {
			return 3;
		}
		return 1;
	}

	void _advanceCard() {
		if (widget.cards.isEmpty) {
			return;
		}
		_cardIndex = (_cardIndex + 1) % widget.cards.length;
		_attemptRevision++;
		_resetTimer();
	}

	void _handleCardResult(bool correct) {
		if (_won || _lost || widget.cards.isEmpty) {
			return;
		}

		if (correct) {
			widget.onAnswerCorrect();
			final Duration elapsed = DateTime.now().difference(_cardShownAt);
			final int damage = _damageFromSpeed(elapsed);
			bool bossDefeated = false;
			setState(() {
				_bossHp = math.max(0, _bossHp - damage);
				_combatText = 'Treffer! Boss erleidet $damage Schaden.';
				_combatTextColor = const m.Color(0xFF66D48B);
				bossDefeated = _bossHp <= 0;
				if (!bossDefeated) {
					_advanceCard();
				}
			});

			if (bossDefeated) {
				widget.onLevelCompleted();
			}
			return;
		}

		widget.onAnswerWrong();
		setState(() {
			_playerHp = math.max(0, _playerHp - 3);
			_bossHp = math.min(_bossMaxHp, _bossHp + 3);
			_combatText = 'Fehler! Du erleidest 3 Schaden, Boss heilt 3.';
			_combatTextColor = const m.Color(0xFFF07A7A);
			if (_playerHp > 0) {
				_advanceCard();
			}
		});
	}

	fw.Widget _buildCard(Card card) {
		if (card is MultipleChoiceCard) {
			return _MultipleChoiceCardView(
				key: fw.ValueKey<String>(
					'boss-mc-${card.levelNumber}-${card.cardNumber}-$_attemptRevision-$_cardIndex',
				),
				card: card,
				onAnswered: _handleCardResult,
			);
		}

		if (card is CodeCard) {
			return _CodeCardView(
				key: fw.ValueKey<String>(
					'boss-code-${card.levelNumber}-${card.cardNumber}-$_attemptRevision-$_cardIndex',
				),
				card: card,
				onSolved: _handleCardResult,
			);
		}

		if (card is ClozeCard) {
			return ClozeWidget(
				key: fw.ValueKey<String>(
					'boss-cloze-${card.levelNumber}-${card.cardNumber}-$_attemptRevision-$_cardIndex',
				),
				card: card,
				onSolved: _handleCardResult,
			);
		}

		return const m.Text('Unbekannter Kartentyp.');
	}

	fw.Widget _buildHealthBar({
		required String label,
		required int hp,
		required int maxHp,
		required m.Color color,
	}) {
		final double value = hp <= 0 ? 0 : hp / maxHp;
		return m.Column(
			crossAxisAlignment: m.CrossAxisAlignment.start,
			children: <fw.Widget>[
				m.Text(
					'$label HP: $hp / $maxHp',
					style: const m.TextStyle(fontWeight: m.FontWeight.w700),
				),
				const m.SizedBox(height: 4),
				m.ClipRRect(
					borderRadius: m.BorderRadius.circular(10),
					child: m.LinearProgressIndicator(
						value: value,
						minHeight: 12,
						backgroundColor: const m.Color(0xFF243041),
						valueColor: m.AlwaysStoppedAnimation<m.Color>(color),
					),
				),
			],
		);
	}

	fw.Widget _buildCombatant({
		required String label,
		required String asset,
		required int hp,
		required int maxHp,
		required m.Color hpColor,
	}) {
		return m.Column(
			crossAxisAlignment: m.CrossAxisAlignment.start,
			children: <fw.Widget>[
				_buildHealthBar(
					label: label,
					hp: hp,
					maxHp: maxHp,
					color: hpColor,
				),
				const m.SizedBox(height: 10),
				m.Expanded(
					child: m.Container(
						padding: const m.EdgeInsets.all(8),
						decoration: m.BoxDecoration(
							color: const m.Color(0xFF101923),
							borderRadius: m.BorderRadius.circular(12),
							border: m.Border.all(color: const m.Color(0xFF2A394B)),
						),
						child: m.Image.asset(
							asset,
							fit: m.BoxFit.contain,
						),
					),
				),
			],
		);
	}

	@override
	fw.Widget build(fw.BuildContext context) {
		return m.Center(
			child: m.ConstrainedBox(
				constraints: const m.BoxConstraints(maxWidth: 960, maxHeight: 740),
				child: m.Material(
					color: const m.Color(0xFF121A24),
					borderRadius: m.BorderRadius.circular(14),
					child: m.Padding(
						padding: const m.EdgeInsets.all(14),
						child: m.Column(
							crossAxisAlignment: m.CrossAxisAlignment.start,
							children: <fw.Widget>[
								m.Row(
									children: <fw.Widget>[
										m.Text(
											'Boss Window - World ${widget.worldNumber}, Level ${widget.levelNumber}',
											style: const m.TextStyle(
												fontSize: 18,
												fontWeight: m.FontWeight.w700,
											),
										),
										const m.Spacer(),
										m.IconButton(
											onPressed: widget.onClose,
											icon: const m.Icon(m.Icons.close),
										),
									],
								),
								if (_combatText != null) ...<fw.Widget>[
									m.Text(
										_combatText!,
										style: m.TextStyle(
											color: _combatTextColor,
											fontWeight: m.FontWeight.w700,
										),
									),
									const m.SizedBox(height: 8),
								],
								if (!widget.loading && widget.cards.isNotEmpty)
									m.Text('Karte $_displayCardIndex / ${widget.cards.length}'),
								const m.SizedBox(height: 10),
								m.Expanded(
									child: m.Column(
										children: <fw.Widget>[
											m.Expanded(
												flex: 3,
												child: m.Container(
													padding: const m.EdgeInsets.all(12),
													decoration: m.BoxDecoration(
														borderRadius: m.BorderRadius.circular(12),
														color: const m.Color(0x11FFFFFF),
														border: m.Border.all(
															color: const m.Color(0x22FFFFFF),
														),
													),
													child: widget.loading
														? const m.Center(
																child: m.CircularProgressIndicator(),
															)
														: (widget.cards.isEmpty
																? const m.Center(
																		child: m.Text(
																			'Für dieses Boss-Level sind noch keine Karten vorhanden.',
																		),
																)
																: (_lost
																		? m.Center(
																				child: m.Column(
																					mainAxisSize: m.MainAxisSize.min,
																					children: <fw.Widget>[
																						const m.Text(
																							'Du wurdest besiegt.',
																							style: m.TextStyle(
																								fontSize: 18,
																								fontWeight: m.FontWeight.w700,
																							),
																						),
																						const m.SizedBox(height: 12),
																						m.Row(
																							mainAxisAlignment: m.MainAxisAlignment.center,
																							children: <fw.Widget>[
																								m.OutlinedButton(
																									onPressed: () {
																									setState(() {
																										_resetFightState();
																									});
																								},
																								child: const m.Text('Nochmal versuchen'),
																							),
																								const m.SizedBox(width: 10),
																								m.FilledButton.tonal(
																									onPressed: widget.onClose,
																								child: const m.Text('Schließen'),
																							),
																						],
																						),
																					],
																				),
																		)
																		: _buildCard(_currentCard!)))),
											),
											const m.SizedBox(height: 12),
											m.Expanded(
												flex: 2,
												child: m.Container(
													padding: const m.EdgeInsets.all(12),
													decoration: m.BoxDecoration(
														borderRadius: m.BorderRadius.circular(12),
														color: const m.Color(0xFF172434),
														border: m.Border.all(
															color: const m.Color(0xFF2B3F56),
														),
													),
													child: m.Row(
														children: <fw.Widget>[
															m.Expanded(
																child: _buildCombatant(
																	label: 'Du',
																	asset: 'assets/Sprite_Goblin.png',
																	hp: _playerHp,
																	maxHp: _playerMaxHp,
																	hpColor: const m.Color(0xFF4DD37C),
																),
															),
															const m.SizedBox(width: 22),
															m.Expanded(
																child: _buildCombatant(
																	label: 'Boss',
																	asset: 'assets/Sprite_VampireLord.png',
																	hp: _bossHp,
																	maxHp: _bossMaxHp,
																	hpColor: const m.Color(0xFFE05252),
																),
															),
														],
													),
												),
											),
										],
									),
								),
							],
						),
					),
				),
			),
		);
	}
}

class MenuPage extends Page {
	const MenuPage({
		super.key,
		required this.onBack,
		required this.onWorld,
		required this.onLearn,
		required this.onDebug,
	});

	final fw.VoidCallback onBack;
	final fw.VoidCallback onWorld;
	final fw.VoidCallback onLearn;
	final fw.VoidCallback onDebug;

	@override
	fw.Widget build(fw.BuildContext context) {
		return _PageShell(
			onBack: onBack,
			child: m.Column(
				mainAxisSize: m.MainAxisSize.min,
				children: <fw.Widget>[
					m.ElevatedButton(
						onPressed: onWorld,
						child: const m.Text('World'),
					),
					const m.SizedBox(height: 12),
					m.ElevatedButton(
						onPressed: onLearn,
						child: const m.Text('Learn'),
					),
					const m.SizedBox(height: 12),
					m.ElevatedButton(
						onPressed: onDebug,
						child: const m.Text('DEBUG'),
					),
				],
			),
		);
	}
}

class DEBUGPage extends Page {
	const DEBUGPage({
		super.key,
		required this.onBack,
	});

	final fw.VoidCallback onBack;

	@override
	fw.Widget build(fw.BuildContext context) {
		return _PageShell(
			onBack: onBack,
			centerChild: false,
			child: const m.Column(
				crossAxisAlignment: m.CrossAxisAlignment.start,
				children: <fw.Widget>[
					m.Text(
						'DEBUG Code Editor',
						style: m.TextStyle(
							fontSize: 20,
							fontWeight: m.FontWeight.w700,
						),
					),
					m.SizedBox(height: 10),
					m.Expanded(
						child: CodeEditWidget(
							initialCode:
								'def solve(a, b):\n    return a + b\n\nprint(solve(2, 3))',
						),
					),
				],
			),
		);
	}
}

class CodeEditWidget extends fw.StatefulWidget {
	const CodeEditWidget({
		super.key,
		this.initialCode = '',
		this.onChanged,
	});

	final String initialCode;
	final fw.ValueChanged<String>? onChanged;

	@override
	fw.State<CodeEditWidget> createState() => _CodeEditWidgetState();
}

class _CodeEditWidgetState extends fw.State<CodeEditWidget> {
	late final CodeController _controller;

	@override
	void initState() {
		super.initState();
		_controller = CodeController(
			text: widget.initialCode,
			language: python_language.python,
		);
		_controller.addListener(_onCodeChanged);
	}

	void _onCodeChanged() {
		widget.onChanged?.call(_controller.text);
	}

	@override
	void dispose() {
		_controller.removeListener(_onCodeChanged);
		_controller.dispose();
		super.dispose();
	}

	@override
	fw.Widget build(fw.BuildContext context) {
		return m.Container(
			decoration: m.BoxDecoration(
				color: const m.Color(0xFF151A22),
				borderRadius: m.BorderRadius.circular(10),
				border: m.Border.all(color: const m.Color(0xFF2E3744)),
			),
			padding: const m.EdgeInsets.all(8),
			child: CodeField(
				controller: _controller,
				textStyle: const m.TextStyle(
					fontFamily: 'monospace',
					fontSize: 15,
					height: 1.35,
				),
			),
		);
	}
}

class LoginPage extends Page {
	const LoginPage({
		super.key,
		required this.onBack,
		required this.controller,
		required this.onLogin,
	});

	final fw.VoidCallback onBack;
	final m.TextEditingController controller;
	final fw.ValueChanged<String> onLogin;

	@override
	fw.Widget build(fw.BuildContext context) {
		return _PageShell(
			onBack: onBack,
			child: m.Column(
				mainAxisSize: m.MainAxisSize.min,
				children: <fw.Widget>[
					m.SizedBox(
						width: 260,
						child: m.TextField(
							controller: controller,
							decoration: const m.InputDecoration(
								labelText: 'Name',
							),
						),
					),
					const m.SizedBox(height: 12),
					m.ElevatedButton(
						onPressed: () => onLogin(controller.text),
						child: const m.Text('Login'),
					),
				],
			),
		);
	}
}

class _PageShell extends fw.StatelessWidget {
	const _PageShell({
		required this.onBack,
		required this.child,
		this.centerChild = true,
		this.rightAction,
	});

	final fw.VoidCallback onBack;
	final fw.Widget child;
	final bool centerChild;
	final fw.Widget? rightAction;

	@override
	fw.Widget build(fw.BuildContext context) {
		return m.Scaffold(
			body: m.SafeArea(
				child: m.Padding(
					padding: const m.EdgeInsets.all(16),
					child: m.Column(
						crossAxisAlignment: m.CrossAxisAlignment.start,
						children: <fw.Widget>[
							m.Row(
								children: <fw.Widget>[
									m.TextButton(
										onPressed: onBack,
										child: const m.Text('Back'),
									),
									const m.Spacer(),
									?rightAction,
								],
							),
							const m.SizedBox(height: 12),
							m.Expanded(
								child: centerChild ? m.Center(child: child) : child,
							),
						],
					),
				),
			),
		);
	}
}

class WorldGrid extends fw.StatelessWidget {
	const WorldGrid({
		super.key,
		required this.world,
		required this.revealConditionMet,
		required this.layoutRevision,
		this.onLevelTap,
	});

	final WorldMapData world;
	final bool revealConditionMet;
	final int layoutRevision;
	final void Function(Node node, bool unlocked)? onLevelTap;

	bool _isNodeVisible(Node node) {
		return true;
	}

	bool _isNodeUnlocked(Node node) {
		if (node.isSecret) {
			return node.revealConditionMet || revealConditionMet;
		}
		if (node.parents.isEmpty) {
			return true;
		}
		return node.parents.every((Node p) => p.level.completed);
	}

	@override
	fw.Widget build(fw.BuildContext context) {
		final int? bossLevelNumber = world.numericNodesInOrder.isEmpty
			? null
			: int.tryParse(world.numericNodesInOrder.last.id);

		return m.LayoutBuilder(
			builder: (fw.BuildContext context, m.BoxConstraints constraints) {
				final double size = math.min(
					constraints.maxWidth,
					constraints.maxHeight,
				);
				final double cellSize = size / 16;

				return m.Center(
					child: m.SizedBox(
						width: size,
						height: size,
						child: m.Stack(
							children: <fw.Widget>[
								m.CustomPaint(
									size: m.Size(size, size),
									painter: _WorldGridPainter(
										world: world,
										revealConditionMet: revealConditionMet,
										cellSize: cellSize,
										layoutRevision: layoutRevision,
									),
								),
								...world.nodesById.values
									.where(_isNodeVisible)
									.map((Node node) {
										final bool unlocked = _isNodeUnlocked(node);
										final bool completed = node.level.completed;
										final int? nodeLevelNumber = int.tryParse(node.id);
										final bool isFinalLevelNode =
											!node.isSecret &&
											nodeLevelNumber != null &&
											bossLevelNumber != null &&
											nodeLevelNumber == bossLevelNumber;
										late final m.Color baseColor;
										late final m.Color borderColor;
										if (isFinalLevelNode) {
											baseColor = completed
												? const m.Color(0xFFE53935)
												: (unlocked
													? const m.Color(0xFFD34E4A)
													: const m.Color(0xFF7F3A38));
											borderColor = const m.Color(0xFF671A18);
										} else {
											baseColor = completed
												? const m.Color(0xFF1FD768)
												: (unlocked
													? const m.Color(0xFF8993A0)
													: const m.Color(0xFF4F5560));
											borderColor = completed
												? const m.Color(0xFF178F45)
												: const m.Color(0xFF2B2F35);
										}

										return m.Positioned(
											left: (node.col * cellSize) + (cellSize * 0.04),
											top: (node.row * cellSize) + (cellSize * 0.04),
											width: cellSize * 0.92,
											height: cellSize * 0.92,
											child: m.GestureDetector(
												onTap: () => onLevelTap?.call(node, unlocked),
												child: m.Container(
													decoration: m.BoxDecoration(
														shape: m.BoxShape.circle,
														color: baseColor,
														border: m.Border.all(
															color: borderColor,
															width: 1.4,
														),
														boxShadow: const <m.BoxShadow>[
															m.BoxShadow(
																color: m.Color(0x33000000),
																blurRadius: 6,
																offset: m.Offset(0, 2),
															),
														],
													),
													child: m.Stack(
														children: <fw.Widget>[
															m.Positioned(
																left: 4,
																top: 4,
																child: m.Container(
																	width: cellSize * 0.22,
																	height: cellSize * 0.22,
																	decoration: const m.BoxDecoration(
																		shape: m.BoxShape.circle,
																		color: m.Color(0x77FFFFFF),
																	),
																),
															),
															m.Center(
																child: node.isSecret
																	? m.Text(
																		'?',
																		style: m.TextStyle(
																			fontWeight: m.FontWeight.w900,
																			fontSize: cellSize * 0.50,
																			color: const m.Color(0xFFFFD54F),
																			shadows: const <m.Shadow>[
																				m.Shadow(
																					color: m.Color(0xAA4A2C00),
																					offset: m.Offset(0, 1),
																					blurRadius: 1,
																				),
																			],
																		),
																	)
																	: m.Text(
																		node.id,
																		style: m.TextStyle(
																			fontWeight: m.FontWeight.w900,
																			fontSize: cellSize * 0.40,
																			color: const m.Color(0xFFF2F2F2),
																			shadows: const <m.Shadow>[
																				m.Shadow(
																					color: m.Color(0x88000000),
																					offset: m.Offset(0, 1),
																					blurRadius: 1,
																				),
																			],
																		),
																	),
															),
														],
													),
												),
											),
										);
									})
									,
							],
						),
					),
				);
			},
		);
	}
}

class _WorldGridPainter extends m.CustomPainter {
	_WorldGridPainter({
		required this.world,
		required this.revealConditionMet,
		required this.cellSize,
		required this.layoutRevision,
	});

	final WorldMapData world;
	final bool revealConditionMet;
	final double cellSize;
	final int layoutRevision;

	m.Path _buildJaggedPath(m.Offset start, m.Offset end) {
		final m.Offset direction = end - start;
		final double length = math.max(direction.distance, 1);
		final m.Offset perpendicular = m.Offset(-direction.dy, direction.dx);
		final m.Offset normal = perpendicular / length;
		final int segments = 8;
		final double amplitude = math.min(cellSize * 0.25, 10);

		final m.Path path = m.Path()..moveTo(start.dx, start.dy);
		for (int i = 1; i <= segments; i++) {
			final double t = i / segments;
			m.Offset point = m.Offset.lerp(start, end, t)!;
			if (i != segments) {
				final double directionSign = i.isEven ? -1 : 1;
				point = point + (normal * amplitude * directionSign);
			}
			path.lineTo(point.dx, point.dy);
		}
		return path;
	}

	@override
	void paint(m.Canvas canvas, m.Size size) {
		final m.Paint gridPaint = m.Paint()
			..color = const m.Color(0x1AFFFFFF)
			..strokeWidth = 1;

		for (int i = 0; i <= 16; i++) {
			final double p = i * cellSize;
			canvas.drawLine(m.Offset(p, 0), m.Offset(p, size.height), gridPaint);
			canvas.drawLine(m.Offset(0, p), m.Offset(size.width, p), gridPaint);
		}

		for (final EdgeLink edge in world.edges) {
			if (edge.hidden && !revealConditionMet) {
				continue;
			}

			final Node? from = world.nodesById[edge.from];
			final Node? to = world.nodesById[edge.to];
			if (from == null || to == null) {
				continue;
			}

			if ((from.isSecret || to.isSecret) && !revealConditionMet) {
				continue;
			}

			final m.Offset start = m.Offset(
				(from.col + 0.5) * cellSize,
				(from.row + 0.5) * cellSize,
			);
			final m.Offset end = m.Offset(
				(to.col + 0.5) * cellSize,
				(to.row + 0.5) * cellSize,
			);
			final bool isSecretPath = from.isSecret || to.isSecret;

			if (isSecretPath) {
				final m.Path jaggedPath = _buildJaggedPath(start, end);
				final m.Paint secretBase = m.Paint()
					..color = const m.Color(0x996B4B00)
					..strokeWidth = cellSize * 0.20
					..style = m.PaintingStyle.stroke
					..strokeCap = m.StrokeCap.round;

				final m.Paint secretTop = m.Paint()
					..color = const m.Color(0xFFE3B435)
					..strokeWidth = cellSize * 0.10
					..style = m.PaintingStyle.stroke
					..strokeCap = m.StrokeCap.round;

				canvas.drawPath(jaggedPath, secretBase);
				canvas.drawPath(jaggedPath, secretTop);
				continue;
			}

			final m.Offset direction = end - start;
			final m.Offset midpoint = start + (direction * 0.5);
			final m.Offset perpendicular = m.Offset(-direction.dy, direction.dx);
			final double length = math.max(direction.distance, 1);
			final double bend = math.min(14, cellSize * 0.45);
			final m.Offset controlPoint = midpoint +
				(perpendicular / length) *
				((edge.from.codeUnitAt(0) + edge.to.codeUnitAt(0)).isEven
					? bend
					: -bend);

			final m.Path path = m.Path()
				..moveTo(start.dx, start.dy)
				..quadraticBezierTo(
					controlPoint.dx,
					controlPoint.dy,
					end.dx,
					end.dy,
				);

			final m.Paint pathBase = m.Paint()
				..color = const m.Color(0x6642B35A)
				..strokeWidth = cellSize * 0.20
				..style = m.PaintingStyle.stroke
				..strokeCap = m.StrokeCap.round;

			final m.Paint pathTop = m.Paint()
				..color = const m.Color(0xCC74D889)
				..strokeWidth = cellSize * 0.10
				..style = m.PaintingStyle.stroke
				..strokeCap = m.StrokeCap.round;

			canvas.drawPath(path, pathBase);
			canvas.drawPath(path, pathTop);
		}
	}

	@override
	bool shouldRepaint(covariant _WorldGridPainter oldDelegate) {
		return oldDelegate.world != world ||
			oldDelegate.revealConditionMet != revealConditionMet ||
			oldDelegate.cellSize != cellSize ||
			oldDelegate.layoutRevision != layoutRevision;
	}
}

class MainPageHost extends fw.StatefulWidget {
	const MainPageHost({super.key});

	@override
	fw.State<MainPageHost> createState() => _MainPageHostState();
}

class _MainPageHostState extends fw.State<MainPageHost> {
	final m.TextEditingController _nameController = m.TextEditingController();
	final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
	User? _currentUser;
	List<WorldMapData> _worlds = <WorldMapData>[];
	List<Card> _questionCards = <Card>[];
	bool _questionCardsLoading = true;
	int? _activeLearnLevel;
	int? _activeLearnWorldNumber;
	_BackgroundTrack _currentBackgroundTrack = _BackgroundTrack.none;
	int _worldLayoutRevision = 0;
	int _selectedWorldIndex = 0;
	final List<Page> _history = <Page>[];
	late final WorldPage _worldPage;
	late final LearnPage _learnPage;
	late final MenuPage _menuPage;
	late final LoginPage _loginPage;
	late final DEBUGPage _debugPage;

	Page get _activePage => _history.last;

	@override
	void initState() {
		super.initState();
		_worldPage = WorldPage(
			levelNodes: const <LevelNode>[],
			onBack: goBack,
			getWorlds: () => _worlds,
			getWorldLayoutRevision: () => _worldLayoutRevision,
			getSelectedWorldIndex: () => _selectedWorldIndex,
			getActiveLearnLevel: _getActiveLearnLevel,
			getLearnWindowCards: _getActiveLearnCards,
			getLearnCardsLoading: _getLearnCardsLoading,
			isWorldUnlocked: _isWorldUnlocked,
			selectWorld: _selectWorld,
			isSecretRevealConditionMet: _isSecretRevealConditionMet,
			isBossLevel: _isBossLevel,
			onLevelNodeTap: _openLearnWindowForLevel,
			onCloseLearnWindow: _closeLearnWindow,
			onAnswerCorrect: _onAnyAnswerCorrect,
			onAnswerWrong: _onAnyAnswerWrong,
			onLearnLevelCompleted: _onLearnLevelCompleted,
			onDebugUnlockNextLevel: _debugUnlockNextLevel,
			onDebugUnlockSecretLevel: _debugUnlockSecretLevel,
		);
		_learnPage = LearnPage(
			onBack: goBack,
			onAnswerCorrect: _onAnyAnswerCorrect,
			onAnswerWrong: _onAnyAnswerWrong,
			onLevelWon: _onAnyLevelWon,
		);
		_debugPage = DEBUGPage(onBack: goBack);
		_menuPage = MenuPage(
			onBack: goBack,
			onWorld: () => switchTo(_worldPage),
			onLearn: () => switchTo(_learnPage),
			onDebug: () => switchTo(_debugPage),
		);
		_loginPage = LoginPage(
			onBack: goBack,
			controller: _nameController,
			onLogin: _handleLogin,
		);
		_history.add(_loginPage);
		_initializeWorlds();
		_initializeQuestionCards();
		unawaited(_refreshBackgroundMusic());
	}

	_BackgroundTrack _desiredBackgroundTrack() {
		final Page activePage = _activePage;
		if (activePage == _worldPage || activePage == _learnPage) {
			final int? worldNumber = _activeLearnWorldNumber;
			final int? levelNumber = _activeLearnLevel;
			if (worldNumber != null &&
				levelNumber != null &&
				_isBossLevel(worldNumber, levelNumber)) {
				return _BackgroundTrack.boss;
			}
			return _BackgroundTrack.world;
		}
		return _BackgroundTrack.none;
	}

	Future<void> _refreshBackgroundMusic() async {
		final _BackgroundTrack nextTrack = _desiredBackgroundTrack();
		if (_currentBackgroundTrack == nextTrack) {
			return;
		}

		_currentBackgroundTrack = nextTrack;
		try {
			if (nextTrack == _BackgroundTrack.none) {
				await _backgroundMusicPlayer.stop();
				return;
			}

			final String asset = nextTrack == _BackgroundTrack.boss
				? 'world1_boss.wav'
				: 'world1.mp3';
			await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
			await _backgroundMusicPlayer.play(
				AssetSource(asset),
				volume: 0.58,
			);
		} catch (_) {
			// Keep gameplay running even if audio playback fails on a platform.
		}
	}

	void _scheduleBackgroundMusicRefresh() {
		unawaited(_refreshBackgroundMusic());
	}

	Future<void> _playOneShotAsset(String assetPath, {double volume = 1.0}) async {
		final AudioPlayer sfxPlayer = AudioPlayer();
		try {
			await sfxPlayer.setReleaseMode(ReleaseMode.stop);
			unawaited(sfxPlayer.onPlayerComplete.first.then((_) {
				return sfxPlayer.dispose();
			}));
			await sfxPlayer.play(AssetSource(assetPath), volume: volume);
		} catch (_) {
			await sfxPlayer.dispose();
		}
	}

	void _onAnyAnswerCorrect() {
		unawaited(_playOneShotAsset('correct_jingle.wav', volume: 0.95));
	}

	void _onAnyAnswerWrong() {
		unawaited(_playOneShotAsset('false_sound.wav', volume: 1.0));
	}

	void _onAnyLevelWon() {
		unawaited(_playOneShotAsset('level_win_sound.wav', volume: 1.0));
	}

	bool _isBossLevel(int worldNumber, int levelNumber) {
		final int worldIndex = _worlds.indexWhere(
			(WorldMapData world) => world.worldNumber == worldNumber,
		);
		if (worldIndex == -1) {
			return false;
		}

		final List<Node> numericNodes = _worlds[worldIndex].numericNodesInOrder;
		if (numericNodes.isEmpty) {
			return false;
		}

		final int? lastLevel = int.tryParse(numericNodes.last.id);
		return lastLevel != null && levelNumber == lastLevel;
	}

	Future<void> _initializeQuestionCards() async {
		try {
			final String raw = await s.rootBundle.loadString('assets/fragen_welt.txt');
			final List<Card> parsed = parseQuestionCardsFromText(raw);

			if (!mounted) {
				return;
			}

			setState(() {
				_questionCards = parsed;
				_questionCardsLoading = false;
				_worldLayoutRevision++;
			});
		} catch (_) {
			if (!mounted) {
				return;
			}
			setState(() {
				_questionCards = <Card>[];
				_questionCardsLoading = false;
				_worldLayoutRevision++;
			});
		}
	}

	int? _getActiveLearnLevel() => _activeLearnLevel;

	bool _getLearnCardsLoading() => _questionCardsLoading;

	List<Card> _getActiveLearnCards() {
		final int? level = _activeLearnLevel;
		final int? world = _activeLearnWorldNumber;
		if (level == null || world == null) {
			return const <Card>[];
		}

		if (_isBossLevel(world, level)) {
			final List<Card> bossPool = _questionCards
				.where(
					(Card card) =>
						_cardWorldNumber(card) == world &&
						_cardLevelNumber(card) < level,
				)
				.toList();
			bossPool.shuffle(math.Random());
			return bossPool;
		}

		return _questionCards
			.where(
				(Card card) =>
					_cardWorldNumber(card) == world && _cardLevelNumber(card) == level,
			)
			.toList();
	}

	void _openLearnWindowForLevel(int worldNumber, int levelNumber) {
		setState(() {
			_activeLearnWorldNumber = worldNumber;
			_activeLearnLevel = levelNumber;
			_worldLayoutRevision++;
		});
		_scheduleBackgroundMusicRefresh();
	}

	void _closeLearnWindow() {
		setState(() {
			_activeLearnWorldNumber = null;
			_activeLearnLevel = null;
			_worldLayoutRevision++;
		});
		_scheduleBackgroundMusicRefresh();
	}

	void _onLearnLevelCompleted(int levelNumber) {
		_onAnyLevelWon();
		final int worldIndex = _worlds.indexWhere(
			(WorldMapData world) => world.worldNumber == (_activeLearnWorldNumber ?? 1),
		);
		if (worldIndex != -1) {
			level_completed(worldIndex: worldIndex, levelId: '$levelNumber');
		}
		_closeLearnWindow();
	}

	Future<void> _initializeWorlds() async {
		final String world1Raw = await s.rootBundle.loadString(
			'assets/world1_map.txt',
		);
		final String world2Raw = await s.rootBundle.loadString(
			'assets/world2_map.txt',
		);
		final String world3Raw = await s.rootBundle.loadString(
			'assets/world3_map.txt',
		);

		final List<WorldMapData> loaded = <WorldMapData>[
			WorldMapData.parse(
				worldNumber: 1,
				raw: world1Raw,
				requiredAchievement: null,
			),
			WorldMapData.parse(
				worldNumber: 2,
				raw: world2Raw,
				requiredAchievement: 'World1Complete',
			),
			WorldMapData.parse(
				worldNumber: 3,
				raw: world3Raw,
				requiredAchievement: 'World2Complete',
			),
		];

		if (!mounted) {
			return;
		}

		setState(() {
			_worlds = loaded;
			_worldLayoutRevision++;
		});
		_scheduleBackgroundMusicRefresh();
	}

	bool _isWorldUnlocked(int worldIndex) {
		if (worldIndex == 0) {
			return true;
		}

		final User? user = _currentUser;
		if (user == null || worldIndex < 0 || worldIndex >= _worlds.length) {
			return false;
		}

		final String? required = _worlds[worldIndex].requiredAchievement;
		if (required == null) {
			return true;
		}
		return user.achievements.contains(required);
	}

	bool _isSecretRevealConditionMet(int worldIndex) {
		final User? user = _currentUser;
		if (user == null) {
			return false;
		}

		final String achievement = 'World${worldIndex + 1}SecretRevealConditionMet';
		final bool met = user.achievements.contains(achievement);
		if (worldIndex >= 0 && worldIndex < _worlds.length) {
			_worlds[worldIndex].secretNode?.revealConditionMet = met;
		}
		return met;
	}

	void _selectWorld(int worldIndex) {
		if (!_isWorldUnlocked(worldIndex)) {
			return;
		}

		setState(() {
			_selectedWorldIndex = worldIndex;
			_activeLearnWorldNumber = null;
			_activeLearnLevel = null;
			_worldLayoutRevision++;
		});
		_scheduleBackgroundMusicRefresh();
	}

	void _debugUnlockNextLevel() {
		if (_worlds.isEmpty) {
			return;
		}

		final WorldMapData world = _worlds[_selectedWorldIndex];
		for (final Node node in world.numericNodesInOrder) {
			final bool unlocked =
				node.parents.isEmpty ||
				node.parents.every((Node p) => p.level.completed);
			if (!node.level.completed && unlocked) {
				level_completed(worldIndex: _selectedWorldIndex, levelId: node.id);
				return;
			}
		}
	}

	void _debugUnlockSecretLevel() {
		if (_worlds.isEmpty || _currentUser == null) {
			return;
		}

		final WorldMapData world = _worlds[_selectedWorldIndex];
		final String achievement =
			'World${world.worldNumber}SecretRevealConditionMet';

		setState(() {
			_addAchievement(achievement);
			world.secretNode?.revealConditionMet = true;
			_worldLayoutRevision++;
		});
	}

	void level_completed({required int worldIndex, required String levelId}) {
		if (worldIndex < 0 || worldIndex >= _worlds.length) {
			return;
		}

		final WorldMapData world = _worlds[worldIndex];
		final Node? node = world.nodesById[levelId];
		if (node == null || node.isSecret || node.level.completed) {
			return;
		}

		setState(() {
			node.level.completed = true;
			_worldLayoutRevision++;
			final String? finalLevelId = world.numericNodesInOrder.isEmpty
				? null
				: world.numericNodesInOrder.last.id;
			if (node.id == finalLevelId) {
				_addAchievement('World${world.worldNumber}Complete');
			}
		});
	}

	void _addAchievement(String achievement) {
		final User? user = _currentUser;
		if (user == null) {
			return;
		}
		if (!user.achievements.contains(achievement)) {
			user.achievements.add(achievement);
		}
	}

	void switchTo(Page page) {
		setState(() {
			if (page != _worldPage) {
				_activeLearnWorldNumber = null;
				_activeLearnLevel = null;
			}
			_history.add(page);
			if (_history.length > 20) {
				_history.removeAt(0);
			}
			_worldLayoutRevision++;
		});
		_scheduleBackgroundMusicRefresh();
	}

	void goBack() {
		if (_history.length > 1) {
			setState(() {
				_history.removeLast();
				if (_history.last != _worldPage) {
					_activeLearnWorldNumber = null;
					_activeLearnLevel = null;
				}
				_worldLayoutRevision++;
			});
			_scheduleBackgroundMusicRefresh();
		}
	}

	void _handleLogin(String rawName) {
		final String name = rawName.trim();
		if (name.isEmpty) {
			return;
		}

		setState(() {
			_currentUser = User(
				assigned_cards: <Card>[],
				achievements: <String>[],
				name: name,
			);
			_selectedWorldIndex = 0;
			_activeLearnWorldNumber = null;
			_activeLearnLevel = null;
			_history.add(_menuPage);
			if (_history.length > 20) {
				_history.removeAt(0);
			}
			_worldLayoutRevision++;
		});
		_scheduleBackgroundMusicRefresh();
	}

	@override
	void dispose() {
		unawaited(_backgroundMusicPlayer.dispose());
		_nameController.dispose();
		super.dispose();
	}

	@override
	fw.Widget build(fw.BuildContext context) {
		return m.MaterialApp(
			debugShowCheckedModeBanner: false,
			home: fw.KeyedSubtree(
				key: fw.ValueKey<String>(
					'${_history.length}:$_selectedWorldIndex:$_worldLayoutRevision',
				),
				child: _activePage,
			),
		);
	}
}
