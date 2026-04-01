import '../models/tool_action.dart';

const coreTools = <ToolAction>[
  ToolAction(
    id: 'merge_pdf',
    title: 'Merge PDF',
    description: 'Combine multiple PDFs into one polished document.',
    icon: 0xe3b7,
  ),
  ToolAction(
    id: 'split_pdf',
    title: 'Split PDF',
    description: 'Break large PDFs into focused page sets.',
    icon: 0xe15b,
  ),
  ToolAction(
    id: 'compress_pdf',
    title: 'Compress PDF',
    description: 'Re-save documents for smaller shareable files.',
    icon: 0xe14d,
  ),
  ToolAction(
    id: 'word_to_pdf',
    title: 'Word to PDF',
    description: 'Convert Word files into polished PDFs.',
    icon: 0xe873,
  ),
  ToolAction(
    id: 'image_to_pdf',
    title: 'Image to PDF',
    description: 'Turn photos and scans into clean PDF output.',
    icon: 0xe3f4,
  ),
  ToolAction(
    id: 'protect_pdf',
    title: 'Protect PDF',
    description: 'Secure documents with password protection.',
    icon: 0xe899,
  ),
  ToolAction(
    id: 'add_page_numbers',
    title: 'Add page numbers',
    description: 'Insert page numbering into PDF documents.',
    icon: 0xe8fd,
  ),
  ToolAction(
    id: 'unlock_pdf',
    title: 'Unlock PDF',
    description: 'Remove restrictions from protected PDFs.',
    icon: 0xe899,
  ),
  ToolAction(
    id: 'edit_pdf',
    title: 'Edit PDF',
    description: 'Modify text and annotations inside PDF files.',
    icon: 0xe3c9,
  ),
  ToolAction(
    id: 'sign_pdf',
    title: 'Sign PDF',
    description: 'Add signatures to PDF contracts and forms.',
    icon: 0xe263,
  ),
];

const advancedTools = <ToolAction>[];
