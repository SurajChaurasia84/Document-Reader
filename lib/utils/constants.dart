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
    id: 'image_to_pdf',
    title: 'Image to PDF',
    description: 'Turn photos and scans into clean PDF output.',
    icon: 0xe3f4,
  ),
  ToolAction(
    id: 'pdf_to_image',
    title: 'PDF to Image',
    description: 'Export PDF pages as high-resolution images.',
    icon: 0xe412,
  ),
  ToolAction(
    id: 'compress_pdf',
    title: 'Compress PDF',
    description: 'Re-save documents for smaller shareable files.',
    icon: 0xe14d,
  ),
];

const advancedTools = <ToolAction>[
  ToolAction(
    id: 'ocr_pdf',
    title: 'OCR PDF',
    description: 'Extract text from scanned PDFs and images.',
    icon: 0xe264,
  ),
  ToolAction(
    id: 'pdf_to_word',
    title: 'PDF to Word',
    description: 'Document export workflow coming in a later update.',
    icon: 0xe873,
  ),
  ToolAction(
    id: 'ai_summarizer',
    title: 'AI Summarizer',
    description: 'Generate concise summaries from document text.',
    icon: 0xe8dc,
  ),
  ToolAction(
    id: 'translate',
    title: 'Translate',
    description: 'Translate extracted content into another language.',
    icon: 0xe8e2,
  ),
  ToolAction(
    id: 'add_watermark',
    title: 'Add watermark',
    description: 'Watermark workflow coming in a later update.',
    icon: 0xeb76,
  ),
];
