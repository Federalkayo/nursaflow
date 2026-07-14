enum DocumentStatus { processing, ready }

class StudyDocument {
  const StudyDocument({
    required this.id,
    required this.title,
    required this.course,
    required this.status,
    this.pageCount = 0,
    this.progress = 0,
  });

  final String id;
  final String title;
  final String course;
  final DocumentStatus status;
  final int pageCount;
  final double progress; // 0..1, quiz/flashcard mastery progress
}

// TODO: replace with a Riverpod StreamProvider backed by Firestore
// (`users/{uid}/documents`) once the backend is wired.
final mockDocuments = [
  const StudyDocument(
    id: 'pediatric-care-fundamentals',
    title: 'Pediatric Care Fundamentals',
    course: 'Pediatrics',
    status: DocumentStatus.ready,
    pageCount: 12,
    progress: 0.65,
  ),
  const StudyDocument(
    id: 'renal-health',
    title: 'Renal Health',
    course: 'Medical-Surgical Nursing',
    status: DocumentStatus.ready,
    pageCount: 18,
    progress: 0.4,
  ),
  const StudyDocument(
    id: 'bioethics-week6',
    title: 'Bioethics — Week 6',
    course: 'Ethics & Professionalism',
    status: DocumentStatus.processing,
  ),
  const StudyDocument(
    id: 'cranial-nerves',
    title: 'Cranial Nerves Overview',
    course: 'Anatomy & Physiology II',
    status: DocumentStatus.ready,
    pageCount: 9,
    progress: 0.9,
  ),
];
