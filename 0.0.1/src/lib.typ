#let _ufac-syllabus-cell-inset = 0.45em

#let _ufac-syllabus-cell(body, inset: _ufac-syllabus-cell-inset, cell-fill: none, cell-align: none) = grid.cell(
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

#let _ufac-syllabus-note(body) = text(size: 0.65em)[(#body).]

#let months = ("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro")

#let get-month-name(date) = months.at(date.month() - 1)

#let _ufac-syllabus-section-counter = counter("ufac-syllabus-section")
#let _ufac-syllabus-topic-counter = counter("ufac-syllabus-topic")

#let _ufac-syllabus-section(body, note: none) = _ufac-syllabus-cell(
  cell-fill: color.rgb("#D9D9D9"),
)[
  #_ufac-syllabus-section-counter.step()
  #context [*#_ufac-syllabus-section-counter.display(). #body: *]
  #if (note != none) [
    #_ufac-syllabus-note(note)
  ]
]

#let _ufac-syllabus-convert-meetings-to-hours(meetings, class-duration, classes-per-meeting) = {
  let total_minutes = meetings * classes-per-meeting * class-duration
  let hours = calc.floor(total_minutes / 60)
  let minutes = calc.rem(total_minutes, 60)
  str(hours) + "h" + if minutes < 10 { "0" } else { "" } + str(minutes) + "m"
}

#let _ufac-syllabus-program-content-unit(title, meetings, topics: [], isTopic: false, subject-classes-per-meeting: 2, subject-class-duration: 50) = (
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



#let ufac-syllabus(
  academic-center: "Centro de Ciências Exatas e Tecnológicas",
  course: "Bacharelado em Engenharia Elétrica",
  instructor: "Fulano de Tal",
  instructor-degree: "Doutor",
  semester: ("202X", "X"),
  subject: "Nome da disciplina",
  subject-code: "CCETXXX",
  subject-hours: "60h",
  subject-class-duration: 50, // 50 minutes
  subject-classes-per-meeting: 2, // 2 classes of 50 minutes each per meeting
  subject-datetime: "13h20 - 15h00 (Tercas e Quintas)",
  credits: ("4", "0", "0"),
  date: datetime.today(),
  prerequisites: (),
  syllabus: [Ementa da disciplina],
  main-objective: "Objetivo geral da disciplina",
  specific-objectives: (
    "Objetivo especifico 1",
    "Objetivo especifico 2",
    "Objetivo especifico 3",
  ),
  program-content: (
    (title: "Título da unidade", topics: [Tópicos da unidade], meetings: 2, isTopic: true),
  ),
  metodology: [Aulas teóricas, exercícios, projetos e simulações em computador.],
  resources: [As aulas serão ministradas, em sua maioria, por meio de slides, com o auxílio do quadro branco ou de um aplicativo que simula um quadro branco (Squid). Ferramentas computacionais poderão ser utilizadas para complementar as aulas e avaliações. O material de apoio, como apostilas e listas de exercícios, será fornecido de forma digital na plataforma Google Classroom.],
  assignments: [],
  main-bibliography: [Bibliografia principal da disciplina],
  complementary-bibliography: [Bibliografia complementar da disciplina],
  body,
) = {
  set page("a4", margin: (left: 2cm, rest: 1cm), numbering: "1")
  set text(lang: "pt", font: "Tex Gyre Heros", size: 12pt)
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
    _ufac-syllabus-cell(assignments),
    _ufac-syllabus-section(
      note: [Lista dos principais livros e periódicos que abordam o conteúdo especificado no plano. Deve ser organizada de acordo com norma da ABNT. Organizar em bibliografia básica e complementar],
    )[Bibliografia],
    _ufac-syllabus-cell[
      *Bibliografia básica* \
      #main-bibliography

      *Bibliografia complementar* \
      #complementary-bibliography
    ],
    _ufac-syllabus-cell()[*Aprovação no Colegiado de Curso:* #_ufac-syllabus-note[Estatuto, Artigo 34, alínea c e Regimento Geral da UFAC, Artigos 59 e Art. 67- Parágrafo 3°]

    #let data = datetime.today()

    #align(center)[
    #v(1em)
    Rio Branco, #data.day() de #get-month-name(data) de #data.year()\
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
