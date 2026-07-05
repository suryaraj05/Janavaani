import { GoogleGenerativeAI, SchemaType } from '@google/generative-ai';
import { TRIAGE_MODEL, TRIAGE_MODEL_FALLBACK } from '@pp/schema';

export const JANAVAANI_DEPARTMENTS = [
  'Municipal Cleanliness',
  'Electrical Department',
  'Water Department',
  'Roads & Infrastructure',
  'Health & Sanitation',
  'Education',
  'Transport & Public Services',
] as const;

const DEPARTMENT_TO_CATEGORY: Record<string, string> = {
  'Water Department': 'water',
  'Roads & Infrastructure': 'roads',
  'Health & Sanitation': 'health',
  'Electrical Department': 'electricity',
  'Municipal Cleanliness': 'sanitation',
  Education: 'education',
  'Transport & Public Services': 'transport',
};

export interface AnalyzeResult {
  isProblemRelated: boolean;
  suggestedTitle: string | null;
  suggestedDescription: string | null;
  suggestedDepartments: string[];
  suggestedPriority: 'low' | 'medium' | 'high' | 'urgent' | null;
  suggestedLocation: string | null;
  suggestedCategory: string | null;
  confidence: number;
  reasoning: string;
}

function stripDataUrl(img: string): { mime: string; data: string } {
  const match = img.match(/^data:(image\/\w+);base64,(.+)$/);
  if (match) return { mime: match[1], data: match[2] };
  return { mime: 'image/jpeg', data: img };
}

function mapDepartments(categories: string[]): string[] {
  const out = new Set<string>();
  for (const cat of categories) {
    const dept = JANAVAANI_DEPARTMENTS.find(
      (d) => DEPARTMENT_TO_CATEGORY[d] === cat.toLowerCase(),
    );
    if (dept) out.add(dept);
  }
  if (out.size === 0) out.add('Municipal Cleanliness');
  return [...out];
}

function mockAnalyze(title: string, description: string): AnalyzeResult {
  const text = `${title} ${description}`.toLowerCase();
  const isProblem =
    text.length > 0 ||
    text.includes('water') ||
    text.includes('road') ||
    text.includes('garbage') ||
    text.includes('electric');
  return {
    isProblemRelated: isProblem || title.length === 0,
    suggestedTitle: title || 'Reported civic issue in the area',
    suggestedDescription:
      description ||
      'Citizen-reported problem requiring constituency attention.',
    suggestedDepartments: text.includes('water')
      ? ['Water Department']
      : ['Municipal Cleanliness'],
    suggestedPriority: 'medium',
    suggestedLocation: null,
    suggestedCategory: 'other',
    confidence: 0.55,
    reasoning: 'Mock analysis — set GEMINI_API_KEY for full AI triage.',
  };
}

export async function analyzeProblemImages(input: {
  title?: string;
  description?: string;
  images: string[];
}): Promise<AnalyzeResult> {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey || input.images.length === 0) {
    return mockAnalyze(input.title ?? '', input.description ?? '');
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const responseSchema = {
    type: SchemaType.OBJECT,
    properties: {
      isProblemRelated: { type: SchemaType.BOOLEAN },
      suggestedTitle: { type: SchemaType.STRING, nullable: true },
      suggestedDescription: { type: SchemaType.STRING, nullable: true },
      suggestedDepartments: {
        type: SchemaType.ARRAY,
        items: { type: SchemaType.STRING },
      },
      suggestedPriority: { type: SchemaType.STRING, nullable: true },
      suggestedLocation: { type: SchemaType.STRING, nullable: true },
      suggestedCategory: { type: SchemaType.STRING, nullable: true },
      confidence: { type: SchemaType.NUMBER },
      reasoning: { type: SchemaType.STRING },
    },
    required: [
      'isProblemRelated',
      'suggestedDepartments',
      'confidence',
      'reasoning',
    ],
  };

  const systemPrompt = `You analyze photos of civic problems in Indian constituencies (Telangana).
Departments (pick 1-3): ${JANAVAANI_DEPARTMENTS.join(', ')}.
Priorities: low, medium, high, urgent.
If images show infrastructure damage, sanitation, water, roads, electricity, or health hazards — isProblemRelated=true.
Return JSON only. suggestedLocation = place name or landmark if visible.`;

  const parts: Array<{ text: string } | { inlineData: { mimeType: string; data: string } }> = [
    {
      text: `Title hint: ${input.title ?? ''}\nDescription hint: ${input.description ?? ''}`,
    },
  ];
  for (const img of input.images.slice(0, 5)) {
    const { mime, data } = stripDataUrl(img);
    parts.push({ inlineData: { mimeType: mime, data } });
  }

  for (const modelId of [TRIAGE_MODEL, TRIAGE_MODEL_FALLBACK]) {
    try {
      const model = genAI.getGenerativeModel({
        model: modelId,
        systemInstruction: systemPrompt,
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema,
        },
      });
      const result = await model.generateContent({ contents: [{ role: 'user', parts }] });
      const parsed = JSON.parse(result.response.text()) as AnalyzeResult;
      parsed.suggestedDepartments = (parsed.suggestedDepartments ?? []).filter((d) =>
        (JANAVAANI_DEPARTMENTS as readonly string[]).includes(d),
      );
      if (parsed.suggestedDepartments.length === 0) {
        parsed.suggestedDepartments = mapDepartments(
          parsed.suggestedCategory ? [parsed.suggestedCategory] : ['other'],
        );
      }
      return parsed;
    } catch (err) {
      console.warn(`analyzeProblemImages failed on ${modelId}:`, err);
    }
  }

  return mockAnalyze(input.title ?? '', input.description ?? '');
}

export function priorityToUrgency(priority: string): string {
  if (priority === 'urgent') return 'safety_critical';
  if (priority === 'high') return 'high';
  if (priority === 'low') return 'low';
  return 'medium';
}

export { DEPARTMENT_TO_CATEGORY };
