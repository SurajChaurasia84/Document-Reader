import 'package:flutter/material.dart';

import '../models/tool_action.dart';

const coreTools = <ToolAction>[
  ToolAction(
    id: 'merge_pdf',
    title: 'Merge PDF',
    description: 'Combine multiple PDFs into one polished document.',
    icon: Icons.merge_type_rounded,
  ),
  ToolAction(
    id: 'split_pdf',
    title: 'Split PDF',
    description: 'Break large PDFs into focused page sets.',
    icon: Icons.content_cut_rounded,
  ),
  ToolAction(
    id: 'compress_pdf',
    title: 'Compress PDF',
    description: 'Re-save documents for smaller shareable files.',
    icon: Icons.compress_rounded,
  ),
  ToolAction(
    id: 'word_to_pdf',
    title: 'Word to PDF',
    description: 'Convert Word files into polished PDFs.',
    icon: Icons.description_rounded,
  ),
  ToolAction(
    id: 'image_to_pdf',
    title: 'Image to PDF',
    description: 'Turn photos and scans into clean PDF output.',
    icon: Icons.image_rounded,
  ),
  ToolAction(
    id: 'protect_pdf',
    title: 'Protect PDF',
    description: 'Secure documents with password protection.',
    icon: Icons.lock_rounded,
  ),
  ToolAction(
    id: 'add_page_numbers',
    title: 'Add page numbers',
    description: 'Insert page numbering into PDF documents.',
    icon: Icons.pin_outlined,
  ),
  ToolAction(
    id: 'unlock_pdf',
    title: 'Unlock PDF',
    description: 'Remove restrictions from protected PDFs.',
    icon: Icons.lock_open_rounded,
  ),
  ToolAction(
    id: 'edit_pdf',
    title: 'Edit PDF',
    description: 'Modify text and annotations inside PDF files.',
    icon: Icons.edit_rounded,
  ),
  ToolAction(
    id: 'sign_pdf',
    title: 'Sign PDF',
    description: 'Add signatures to PDF contracts and forms.',
    icon: Icons.draw_rounded,
  ),
];

const advancedTools = <ToolAction>[];
