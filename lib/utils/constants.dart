import '../models/subscription_plan.dart';
import '../models/tool_action.dart';

const subscriptionPlans = <SubscriptionPlan>[
  SubscriptionPlan(
    id: 'doc_reader_weekly',
    title: 'Weekly',
    priceLabel: '₹99',
    description: 'Quick premium boost for scanning or edits.',
  ),
  SubscriptionPlan(
    id: 'doc_reader_monthly',
    title: 'Monthly',
    priceLabel: '₹199',
    description: 'Flexible premium access for everyday work.',
  ),
  SubscriptionPlan(
    id: 'doc_reader_yearly',
    title: 'Yearly',
    priceLabel: '₹999',
    description: 'Best value for frequent reading and productivity.',
  ),
  SubscriptionPlan(
    id: 'doc_reader_lifetime',
    title: 'Lifetime',
    priceLabel: '₹4999',
    description: 'One-time purchase with long-term access.',
  ),
];

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

const premiumTools = <ToolAction>[
  ToolAction(
    id: 'ocr_pdf',
    title: 'OCR PDF',
    description: 'Extract text from scanned PDFs and images.',
    icon: 0xe264,
    isPremium: true,
  ),
  ToolAction(
    id: 'pdf_to_word',
    title: 'PDF to Word',
    description: 'Premium export reserved for paid users.',
    icon: 0xe873,
    isPremium: true,
  ),
  ToolAction(
    id: 'ai_summarizer',
    title: 'AI Summarizer',
    description: 'Generate concise summaries from document text.',
    icon: 0xe8dc,
    isPremium: true,
  ),
  ToolAction(
    id: 'translate',
    title: 'Translate',
    description: 'Translate extracted content into another language.',
    icon: 0xe8e2,
    isPremium: true,
  ),
  ToolAction(
    id: 'add_watermark',
    title: 'Add watermark',
    description: 'Premium branding workflow for exports.',
    icon: 0xeb76,
    isPremium: true,
  ),
];
