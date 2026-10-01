#import "@local/ufac-syllabus:0.0.2": *

// Os dados podem vir de um arquivo, com `data: json("plano.json")`, ou de um dicionário, como abaixo.
#show: ufac-syllabus.with(
  data: (
    instructor: "Fulano de Tal",
    semester: (2026, 1),
    subject: "Nome da disciplina",
    subject-code: "CCETXXX",
    subject-hours: "60h",
    credits: ("4", "0", "0"),
    prerequisites: ("CCETYYY",),
    subject-datetime: "13h20 – 15h00 (Terças e Quintas)",
    syllabus: ("Primeiro item da ementa.", "Segundo item da ementa."),
    main-objective: "Objetivo geral da disciplina.",
    specific-objectives: ("Objetivo específico 1;", "Objetivo específico 2."),
    program-content: (
      (
        title: "Título da unidade",
        meetings: 29,
        period: ("01/03/2026", "30/06/2026"),
        holidays: ((date: "21/04/2026", name: "Tiradentes"),),
        topics: ("Primeiro tópico;", "Segundo tópico."),
      ),
      (grade: "P_1", title: "Prova", meetings: 1, isTopic: false, date: "01/07/2026"),
    ),
    evaluations: (
      (grade: "A_1", title: "Atividades propostas", date: "01/03/2026 a 30/06/2026"),
      (title: "Prova final", date: "08/07/2026"),
    ),
    bibliography: (
      main: ("SOBRENOME, Nome. Título. Editora, ano.",),
      complementary: ("SOBRENOME, Nome. Título. Editora, ano.",),
    ),
  ),
  assignments: [
    A nota final será dada por $N = (A_1 + P_1)/2$.
  ],
)
