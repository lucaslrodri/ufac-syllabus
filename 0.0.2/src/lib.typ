/// Padding of the form cells.
/// -> length
#let _ufac-syllabus-cell-inset = 0.45em

/// Font stacks: New Computer Modern first, then fonts embedded in the Typst CLI.
/// -> dictionary
#let _ufac-syllabus-fonts = (
  serif: ("New Computer Modern", "Libertinus Serif"),
  sans: ("New Computer Modern Sans", "New Computer Modern", "Libertinus Serif"),
  math: ("New Computer Modern Math",),
)

/// Fails with a readable message unless `value` has one of the given types.
/// -> none
#let _ufac-syllabus-assert-type(
  /// Name shown in the message, e.g. `"semester"` or `"program-content[2].meetings"`. -> str
  name,
  /// Value to check. -> any
  value,
  /// Accepted types. -> type
  ..types,
) = assert(
  type(value) in types.pos(),
  message: "ufac-syllabus: `" + name + "` must be " + types.pos().map(repr).join(", ", last: " or ") + ", got " + repr(type(value)),
)

/// Fails with a readable message unless `value` is a dictionary holding every one of `keys`.
/// -> none
#let _ufac-syllabus-assert-keys(
  /// Name shown in the message. -> str
  name,
  /// Value to check. -> any
  value,
  /// Required keys. -> str
  ..keys,
) = {
  _ufac-syllabus-assert-type(name, value, dictionary)
  let missing = keys.pos().filter(key => key not in value)
  assert(
    missing.len() == 0,
    message: "ufac-syllabus: `" + name + "` is missing " + missing.map(key => "`" + key + "`").join(" and "),
  )
}

/// A bordered cell of the form.
/// -> content
#let _ufac-syllabus-cell(
  /// Content of the cell. -> content
  body,
  /// Padding of the cell. -> length
  inset: _ufac-syllabus-cell-inset,
  /// Background of the cell. -> none | color
  cell-fill: none,
  /// Alignment of the content; `none` keeps the default. -> none | alignment
  cell-align: none,
) = grid.cell(
  inset: inset,
  fill: cell-fill,
  stroke: 1.5pt,
)[
  #if (cell-align != none) {
    align(cell-align, body)
  } else {
    body
  }
]

/// Small parenthesized explanation that follows a section title.
/// -> content
#let _ufac-syllabus-note(
  /// Text of the note, without the parentheses. -> content
  body,
) = text(size: 0.65em)[(#body).]

/// Month names in Portuguese, January first.
/// -> array
#let months = ("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro")

/// Portuguese name of the month of `date`.
/// -> str
#let get-month-name(
  /// Date whose month is named. -> datetime
  date,
) = months.at(date.month() - 1)

/// Numbers the sections of the form ("1. Ementa", "2. Objetivo geral", …).
/// -> counter
#let _ufac-syllabus-section-counter = counter("ufac-syllabus-section")
/// Numbers the units of the program content ("Unidade temática N").
/// -> counter
#let _ufac-syllabus-topic-counter = counter("ufac-syllabus-topic")

/// Gray, numbered title row of a section.
/// -> content
#let _ufac-syllabus-section(
  /// Title of the section. -> content
  body,
  /// Explanation shown after the title. -> none | content
  note: none,
) = _ufac-syllabus-cell(
  cell-fill: color.rgb("#D9D9D9"),
)[
  #_ufac-syllabus-section-counter.step()
  #context [*#_ufac-syllabus-section-counter.display(). #body: *]
  #if (note != none) [
    #_ufac-syllabus-note(note)
  ]
]

/// Workload of a number of meetings, as `"13h20m"`.
/// -> str
#let _ufac-syllabus-convert-meetings-to-hours(
  /// Number of meetings. -> int
  meetings,
  /// Minutes per class. -> int
  class-duration,
  /// Classes per meeting. -> int
  classes-per-meeting,
) = {
  let total_minutes = meetings * classes-per-meeting * class-duration
  let hours = calc.floor(total_minutes / 60)
  let minutes = calc.rem(total_minutes, 60)
  str(hours) + "h" + if minutes < 10 { "0" } else { "" } + str(minutes) + "m"
}

/// The `data` argument as a dictionary: a dictionary is used as is, a path or raw JSON bytes are parsed.
/// -> dictionary
#let _ufac-syllabus-load(
  /// The `data` argument of `ufac-syllabus`. -> none | dictionary | path | bytes
  data,
) = {
  if data == none { return (:) }
  if type(data) == dictionary { return data }
  assert(
    type(data) != str,
    message: "ufac-syllabus: `data` must be a dictionary, a path or JSON bytes, e.g. `data: json(\"plano.json\")`",
  )
  let loaded = json(data)
  _ufac-syllabus-assert-type("data", loaded, dictionary)
  loaded
}

/// Running text: an array of sentences is joined by spaces, anything else passes through.
/// -> str | content
#let _ufac-syllabus-text(
  /// Sentences or text. -> array | str | content
  value,
) = if type(value) == array { value.join(" ") } else { value }

/// Numbered list: an array becomes one item per element, anything else passes through.
/// -> content
#let _ufac-syllabus-numbered(
  /// Items or ready-made content. -> array | content
  items,
) = if type(items) == array [
  #for item in items [
    + #item
  ]
] else {
  items
}

/// Title of an entry, preceded by its `grade` symbol when it has one: `(grade: "P_1", title: "Prova")` gives "P₁ – Prova".
/// -> str | content
#let _ufac-syllabus-graded-title(
  /// Entry with `title` and, optionally, `grade` (math source). -> dictionary
  item,
  /// Name of the entry in error messages. -> str
  name,
) = {
  let title = item.at("title")
  if "grade" not in item { return title }
  _ufac-syllabus-assert-type(name + ".grade", item.at("grade"), str)
  [#eval(item.at("grade"), mode: "math") – #title]
}

/// A program-content entry ready to render: checks it, builds its title and joins topics, period, holidays, make-up
/// meetings and date into the content shown under the title.
/// -> dictionary
#let _ufac-syllabus-unit(
  /// Entry of `program-content`. -> dictionary
  item,
  /// Position of the entry, for error messages. -> int
  index: 0,
) = {
  let name = "program-content[" + str(index) + "]"
  _ufac-syllabus-assert-keys(name, item, "title", "meetings")
  let topics = item.at("topics", default: ())
  let period = item.at("period", default: none)
  let date = item.at("date", default: none)
  let holidays = item.at("holidays", default: ())
  let makeup = item.at("makeup", default: 0)
  let is-topic = item.at("isTopic", default: true)
  let break-after = item.at("break-after", default: false)

  _ufac-syllabus-assert-type(name + ".meetings", item.at("meetings"), int)
  _ufac-syllabus-assert-type(name + ".topics", topics, array, content, str)
  _ufac-syllabus-assert-type(name + ".isTopic", is-topic, bool)
  _ufac-syllabus-assert-type(name + ".break-after", break-after, bool)
  _ufac-syllabus-assert-type(name + ".holidays", holidays, array)
  _ufac-syllabus-assert-type(name + ".makeup", makeup, int)
  if period != none {
    _ufac-syllabus-assert-type(name + ".period", period, array)
    assert(
      period.len() == 2,
      message: "ufac-syllabus: `" + name + ".period` must be (start, end), got " + repr(period),
    )
  }
  for (i, holiday) in holidays.enumerate() {
    _ufac-syllabus-assert-keys(name + ".holidays[" + str(i) + "]", holiday, "date", "name")
  }

  (
    title: _ufac-syllabus-graded-title(item, name),
    meetings: item.at("meetings"),
    isTopic: is-topic,
    break-after: break-after,
    topics: [
      #if type(topics) != array {
        topics
      } else if topics.len() > 0 {
        list(..topics.map(topic => [#topic]))
      }
      #if period != none [
        #text(size: 0.85em)[
          _Período: #period.at(0) a #period.at(1)_
          #if holidays.len() > 0 [
            \ _#if holidays.len() == 1 [Feriado] else [Feriados]:
            #holidays.map(item => item.at("date") + " (" + item.at("name") + ")").join(", ", last: " e ")_
          ]
          #if makeup > 0 [
            \ _Reposição: #makeup #if makeup == 1 [encontro] else [encontros] com data a definir_
          ]
        ]
      ]
      #if date != none [
        #text(size: 0.85em)[_Data: #(date)_]
      ]
    ],
  )
}

/// Table of evaluations and their dates, kept on a single page.
/// -> content
#let _ufac-syllabus-evaluations(
  /// Rows: dictionaries with `title`, `date` and, optionally, `grade`. -> array
  items,
) = block(breakable: false, table(
  columns: (1fr, auto),
  align: (left + horizon, center + horizon),
  table.header([*Avaliação da aprendizagem*], [*Data de realização*]),
  ..items
    .enumerate()
    .map(((i, item)) => {
      let name = "evaluations[" + str(i) + "]"
      _ufac-syllabus-assert-keys(name, item, "title", "date")
      (_ufac-syllabus-graded-title(item, name), [#item.at("date")])
    })
    .flatten(),
))

/// The two cells of a program-content row: title with details, and workload.
/// -> array
#let _ufac-syllabus-program-content-unit(
  /// Title of the entry. -> str | content
  title,
  /// Number of meetings. -> int
  meetings,
  /// Details shown under the title. -> content
  topics: [],
  /// Whether the entry is a numbered unit ("Unidade temática N – …") rather than an exam. -> bool
  isTopic: false,
  /// Classes per meeting. -> int
  subject-classes-per-meeting: 2,
  /// Minutes per class. -> int
  subject-class-duration: 50,
) = (
  [
    #if (isTopic == true) [
      #_ufac-syllabus-topic-counter.step()
      #context [*Unidade temática #_ufac-syllabus-topic-counter.display() – #title*]
    ] else [
      *#title*
    ] \
    #topics
  ],
  [
    #meetings encontros \
    #(meetings * subject-classes-per-meeting) aulas \
    #_ufac-syllabus-convert-meetings-to-hours(meetings, subject-class-duration, subject-classes-per-meeting)
  ],
)

/// The UFAC course plan ("Plano de curso"), as a show rule. The form is built from the arguments; the document body is
/// not used.
///
/// The fields come from `data`, from the arguments, or from both: an explicit argument wins over `data`, which wins
/// over a placeholder. `data` uses the argument names as keys, with the bibliography under `bibliography`:
///
/// ```typ
/// // From a JSON file
/// #show: ufac-syllabus.with(data: json("plano.json"), assignments: [A média final será …])
///
/// // From a dictionary
/// #show: ufac-syllabus.with(data: (
///   subject: "Microprocessadores",
///   semester: (2026, 2),
///   program-content: (
///     (title: "Introdução", meetings: 4, topics: ("Histórico;", "Arquitetura.")),
///     (grade: "P_1", title: "Prova", meetings: 1, isTopic: false, date: "18/12/2026"),
///   ),
///   bibliography: (main: ("TANENBAUM, A. S. …",), complementary: ()),
/// ))
/// ```
/// -> content
#let ufac-syllabus(
  /// Fields of the plan, either flat or nested as `(course: (..), bibliography: (..))`: a dictionary such as
  /// `json("plano.json")`, a `path` or raw JSON bytes. A path given as a string is rejected, because it would be
  /// resolved inside the package. -> none | dictionary | path | bytes
  data: none,
  /// Text font: `"sans"` or `"serif"` for New Computer Modern, or any font family. -> str | array
  font: "sans",
  /// Academic center. -> auto | str | content
  academic-center: auto,
  /// Degree program. -> auto | str | content
  course: auto,
  /// Name of the instructor. -> auto | str | content
  instructor: auto,
  /// Academic degree of the instructor. -> auto | str | content
  instructor-degree: auto,
  /// Year and term, as `(2026, 2)`. -> auto | array
  semester: auto,
  /// Name of the subject. -> auto | str | content
  subject: auto,
  /// Code of the subject, e.g. `"CCET495"`. -> auto | str | content
  subject-code: auto,
  /// Official workload shown in the header, e.g. `"90h"`. -> auto | str | content
  subject-hours: auto,
  /// Minutes per class. -> auto | int
  subject-class-duration: auto,
  /// Classes per meeting. -> auto | int
  subject-classes-per-meeting: auto,
  /// Class schedule, e.g. `"13h20 – 15h00 (Terças e Quintas)"`. -> auto | str | content
  subject-datetime: auto,
  /// Credits, as `("4", "0", "0")`. -> auto | array
  credits: auto,
  /// Date shown above the signature. -> datetime
  date: datetime.today(),
  /// Prerequisite subjects. -> auto | array
  prerequisites: auto,
  /// Summary of the subject ("Ementa"); an array of sentences is joined into running text. -> auto | array | str | content
  syllabus: auto,
  /// General objective; an array of sentences is joined into running text. -> auto | array | str | content
  main-objective: auto,
  /// Specific objectives, one bullet each. -> auto | array
  specific-objectives: auto,
  /// Units and exams, in order. Each entry is a dictionary with `title` and `meetings` and, optionally: `topics` (an
  /// array, one bullet each, or content), `isTopic` (`false` for an exam; default `true`), `grade` (math source typeset
  /// before the title, e.g. `"P_1"`), `period` (`(start, end)`), `holidays` (array of `(date: .., name: ..)`), `makeup`
  /// (meetings still to be scheduled), `date` and `break-after` (page break after the entry). -> auto | array
  program-content: auto,
  /// Teaching methods; an array of sentences is joined into running text. -> auto | array | str | content
  metodology: auto,
  /// Teaching resources; an array of sentences is joined into running text. -> auto | array | str | content
  resources: auto,
  /// Evaluation criteria; an array of sentences is joined into running text. -> auto | array | str | content
  assignments: auto,
  /// Rows of the table shown after `assignments`: dictionaries with `title`, `date` and, optionally, `grade`. An empty
  /// array hides the table. -> auto | array
  evaluations: auto,
  /// Basic bibliography: an array, one numbered item each, or content. In `data`: `bibliography.main`. -> auto | array | content
  main-bibliography: auto,
  /// Complementary bibliography, like `main-bibliography`. In `data`: `bibliography.complementary`. -> auto | array | content
  complementary-bibliography: auto,
  /// Suggested bibliography, like `main-bibliography`; `none` hides it. In `data`: `bibliography.suggested`. -> auto | none | array | content
  suggested-bibliography: auto,
  /// Ignored: the form is built from the arguments. -> content
  body,
) = {
  let data = _ufac-syllabus-load(data)
  let fields = if type(data.at("course", default: none)) == dictionary { data.at("course") } else { data }
  let references = data.at("bibliography", default: (:))
  _ufac-syllabus-assert-type("data.bibliography", references, dictionary)
  let pick(value, key, default, from: fields) = if value != auto { value } else { from.at(key, default: default) }

  let academic-center = pick(academic-center, "academic-center", "Centro de Ciências Exatas e Tecnológicas")
  let course = pick(course, "course", "Bacharelado em Engenharia Elétrica")
  let instructor = pick(instructor, "instructor", "Fulano de Tal")
  let instructor-degree = pick(instructor-degree, "instructor-degree", "Doutor")
  let semester = pick(semester, "semester", ("202X", "X"))
  let subject = pick(subject, "subject", "Nome da disciplina")
  let subject-code = pick(subject-code, "subject-code", "CCETXXX")
  let subject-hours = pick(subject-hours, "subject-hours", "60h")
  let subject-class-duration = pick(subject-class-duration, "subject-class-duration", 50)
  let subject-classes-per-meeting = pick(subject-classes-per-meeting, "subject-classes-per-meeting", 2)
  let subject-datetime = pick(subject-datetime, "subject-datetime", "13h20 - 15h00 (Tercas e Quintas)")
  let credits = pick(credits, "credits", ("4", "0", "0"))
  let prerequisites = pick(prerequisites, "prerequisites", ())
  let syllabus = _ufac-syllabus-text(pick(syllabus, "syllabus", [Ementa da disciplina]))
  let main-objective = _ufac-syllabus-text(pick(main-objective, "main-objective", "Objetivo geral da disciplina"))
  let specific-objectives = pick(
    specific-objectives,
    "specific-objectives",
    ("Objetivo especifico 1", "Objetivo especifico 2", "Objetivo especifico 3"),
  )
  let program-content = pick(
    program-content,
    "program-content",
    ((title: "Título da unidade", topics: [Tópicos da unidade], meetings: 2, isTopic: true),),
  )
  let metodology = _ufac-syllabus-text(pick(
    metodology,
    "metodology",
    [Aulas teóricas, exercícios, projetos e simulações em computador.],
  ))
  let resources = _ufac-syllabus-text(pick(
    resources,
    "resources",
    [As aulas serão ministradas, em sua maioria, por meio de slides, com o auxílio do quadro branco ou de um aplicativo que simula um quadro branco (Squid). Ferramentas computacionais poderão ser utilizadas para complementar as aulas e avaliações. O material de apoio, como apostilas e listas de exercícios, será fornecido de forma digital na plataforma Google Classroom.],
  ))
  let assignments = _ufac-syllabus-text(pick(assignments, "assignments", []))
  let evaluations = pick(evaluations, "evaluations", ())
  let main-bibliography = pick(main-bibliography, "main", [Bibliografia principal da disciplina], from: references)
  let complementary-bibliography = pick(
    complementary-bibliography,
    "complementary",
    [Bibliografia complementar da disciplina],
    from: references,
  )
  let suggested-bibliography = pick(suggested-bibliography, "suggested", none, from: references)

  _ufac-syllabus-assert-type("font", font, str, array)
  _ufac-syllabus-assert-type("date", date, datetime)
  _ufac-syllabus-assert-type("semester", semester, array)
  assert(semester.len() == 2, message: "ufac-syllabus: `semester` must be (year, term), got " + repr(semester))
  _ufac-syllabus-assert-type("credits", credits, array)
  _ufac-syllabus-assert-type("prerequisites", prerequisites, array)
  _ufac-syllabus-assert-type("subject-class-duration", subject-class-duration, int)
  _ufac-syllabus-assert-type("subject-classes-per-meeting", subject-classes-per-meeting, int)
  _ufac-syllabus-assert-type("specific-objectives", specific-objectives, array)
  _ufac-syllabus-assert-type("program-content", program-content, array)
  _ufac-syllabus-assert-type("evaluations", evaluations, array)
  _ufac-syllabus-assert-type("main-bibliography", main-bibliography, array, content, str)
  _ufac-syllabus-assert-type("complementary-bibliography", complementary-bibliography, array, content, str)
  _ufac-syllabus-assert-type("suggested-bibliography", suggested-bibliography, type(none), array, content, str)

  let program-content = program-content.enumerate().map(((i, item)) => _ufac-syllabus-unit(item, index: i))

  set page("a4", margin: (left: 2cm, rest: 1cm), numbering: "1")
  let font = if font in ("sans", "serif") { _ufac-syllabus-fonts.at(font) } else { font }
  set text(lang: "pt", font: font, size: 12pt)
  show math.equation: set text(font: _ufac-syllabus-fonts.math)
  set par(justify: true)

  let total-meetings = program-content.fold(0, (total, content) => total + content.meetings)

  // Renders the inner program-content table for a slice of items
  let render-pc-table(items, show-total: false) = table(
    columns: (1fr, 8em),
    stroke: 1.5pt,
    inset: _ufac-syllabus-cell-inset,
    align: (left + horizon, center + horizon),
    table.header(table.cell(align: center)[*UNIDADES TEMÁTICAS*], [*C/H*]),
    ..items
      .map(content => _ufac-syllabus-program-content-unit(
        content.title,
        content.meetings,
        topics: content.at("topics", default: []),
        subject-classes-per-meeting: subject-classes-per-meeting,
        subject-class-duration: subject-class-duration,
        isTopic: content.at("isTopic", default: true),
      ))
      .flatten(),
    ..if show-total {
      (
        [*Carga horária total:*],
        [
          #total-meetings encontros \
          #(total-meetings * subject-classes-per-meeting) aulas \
          #_ufac-syllabus-convert-meetings-to-hours(total-meetings, subject-class-duration, subject-classes-per-meeting)
        ],
      )
    } else {
      ()
    },
  )

  // Split program-content into segments at every break-after: true entry
  let segments = {
    let segs = ()
    let start = 0
    for (i, c) in program-content.enumerate() {
      if c.at("break-after", default: false) {
        segs.push(program-content.slice(start, i + 1))
        start = i + 1
      }
    }
    segs.push(program-content.slice(start))
    segs
  }

  let pre-cells = (
    grid.cell(stroke: 1.5pt, inset: 0pt)[
      #grid(
        columns: (4cm, 1fr),
        align: center + horizon,
        inset: _ufac-syllabus-cell-inset,
        stroke: 1.5pt,
        image("../assets/ufac.png", height: 2cm),
        align(center)[
          UNIVERSIDADE FEDERAL DO ACRE \
          PRO-REITORIA DE GRADUACAO \
          DIRETORIA DE APOIO AO DESENVOLVIMENTO DO ENSINO \
        ],
      )
    ],
    _ufac-syllabus-cell(cell-align: center)[*PLANO DE CURSO*],
    grid.cell(stroke: 1.5pt, inset: 0pt)[
      #table(
        columns: (auto, 8em, 8em, 4em, 1fr, 7em),
        stroke: 0.5pt,
        inset: (left: _ufac-syllabus-cell-inset * 1.25, right: _ufac-syllabus-cell-inset * 1.25),
        [*Centro:*], table.cell(colspan: 5, academic-center),
        [*Curso:*], table.cell(colspan: 5, course),
        [*Disciplina:*], table.cell(colspan: 5, subject),
        [*Codigo:*], table.cell(align: center, subject-code),
        [*Carga horaria:*], table.cell(align: center, subject-hours),
        [*Creditos:*], table.cell(align: center, credits.join(" - ")),
        [*Pre-requisitos:*], table.cell(colspan: 2, align: center, prerequisites.join(", ")),
        table.cell(colspan: 2)[*Semestre/Ano letivo:*], table.cell(align: center)[#semester.at(1)º/#semester.at(0)],
        [*Professor:*], table.cell(colspan: 3, instructor),
        [*Titulacao:*], table.cell(align: center, instructor-degree),
        [*Horario:*], table.cell(colspan: 5, align: center, subject-datetime),
      )
    ],
    _ufac-syllabus-section(note: [Síntese do conteúdo da disciplina que consta no Projeto Pedagógico do Curso])[Ementa],
    _ufac-syllabus-cell(syllabus),
    _ufac-syllabus-section(note: [Aprendizagem esperada dos alunos ao concluir a disciplina])[Objetivo geral],
    _ufac-syllabus-cell(main-objective),
    _ufac-syllabus-section(
      note: [Habilidades esperadas dos alunos ao concluir cada unidade/assunto],
    )[Objetivos especificos],
    _ufac-syllabus-cell[
      Ao final do curso o aluno deverá ser capaz de:
      #for objective in specific-objectives [
        - #objective
      ]
    ],
    _ufac-syllabus-section(
      note: [Detalhamento da ementa em unidades de estudo, com distribuição de horas para cada unidade],
    )[Conteúdo programático],
  )

  let post-cells = (
    _ufac-syllabus-section(
      note: [Descrição de como a disciplina será desenvolvida, especificando-se as técnicas de ensino a serem utilizadas],
    )[Procedimentos metodológicos],
    _ufac-syllabus-cell(metodology),
    _ufac-syllabus-section(note: [Especificar os recursos utilizados])[Recursos didáticos],
    _ufac-syllabus-cell(resources),
    _ufac-syllabus-section(
      note: [Descrição dos instrumentos e critérios a serem utilizados para verificação da aprendizagem e aprovação dos alunos],
    )[Avaliação],
    _ufac-syllabus-cell[
      #assignments

      #if evaluations.len() > 0 {
        _ufac-syllabus-evaluations(evaluations)
      }
    ],
    _ufac-syllabus-section(
      note: [Lista dos principais livros e periódicos que abordam o conteúdo especificado no plano. Deve ser organizada de acordo com norma da ABNT. Organizar em bibliografia básica e complementar],
    )[Bibliografia],
    _ufac-syllabus-cell[
      *Bibliografia básica* \
      #_ufac-syllabus-numbered(main-bibliography)

      #v(2em)

      *Bibliografia complementar* \
      #_ufac-syllabus-numbered(complementary-bibliography)

      #if suggested-bibliography != none [
        #v(2em)

        #block(sticky: true, below: 0.65em)[*Bibliografia sugerida*]
        #_ufac-syllabus-numbered(suggested-bibliography)
      ]
    ],
    _ufac-syllabus-cell()[*Aprovação no Colegiado de Curso:* #_ufac-syllabus-note[Estatuto, Artigo 34, alínea c e Regimento Geral da UFAC, Artigos 59 e Art. 67- Parágrafo 3°]

    #align(center)[
    #v(1em)
    Rio Branco, #date.day() de #get-month-name(date) de #date.year()\
    Local e data

    #v(5em)
    Nome e assinatura do professor
    #v(1em)
    ]
    ],
  )

  if segments.len() == 1 {
    // No forced breaks — original single-grid layout
    grid(
      ..pre-cells,
      _ufac-syllabus-cell(inset: 0pt)[#render-pc-table(segments.at(0), show-total: true)],
      ..post-cells,
    )
  } else {
    // First grid: header sections + first program-content segment
    grid(
      ..pre-cells,
      _ufac-syllabus-cell(inset: 0pt)[#render-pc-table(segments.at(0))],
    )
    // Middle segments (more than one break-after)
    for i in range(1, segments.len() - 1) {
      pagebreak()
      grid(
        _ufac-syllabus-cell(inset: 0pt)[#render-pc-table(segments.at(i))],
      )
    }
    // Last segment + rest of document
    pagebreak()
    grid(
      _ufac-syllabus-cell(inset: 0pt)[#render-pc-table(segments.last(), show-total: true)],
      ..post-cells,
    )
  }
}
