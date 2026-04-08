import Foundation

enum PromptGenerator {
    static let defaultTemplate = """
        <ui-motion-reference>
          <source-material>
          Analyze the frame sequence in @"{{path}}".
          Treat the saved images as the primary source of visual truth for layout, appearance, visible state, and motion.
          Use @"{{path}}/session.json" as the authoritative source for timing, capture settings, frame segments, and recorded interaction events.
          Read the `_legend` field in session.json for field descriptions.
          </source-material>

          <analysis-rules>
          Analyze the sequence as time-based motion, not just as a set of static keyframes.
          Pay attention to both macro motion and micro-motion across consecutive frames.

          Explicitly inspect:
          - layout, geometry, spacing, and layering
          - timing, pacing, delays, and easing
          - interaction-triggered state changes
          - persistent ambient motion while the overall composition appears stable
          - per-element changes in opacity, brightness, color, blur, scale, position, distortion, or phase

          If `settings.interactionCapture` is `true`, use recorded interaction events only to infer user intent and trigger UI state changes.
          If `settings.interactionCapture` is `false`, do not assume pointer or keyboard events beyond what is visually evident in the frames.

          When a behavior is uncertain because of capture interval, missing frames, compression, or ambiguity, state that uncertainty explicitly.
          Do not present inference as direct observation.
          </analysis-rules>

          <output-boundaries>
          Reproduce or describe the product UI behavior, not the capture artifact itself.
          Do not recreate a synthetic mouse cursor, click indicator, drag overlay, capture flash, or recording artifact unless it is clearly part of the actual product UI.

          Preserve meaningful ongoing motion even when the screen appears visually stable.
          Do not treat shimmer, flicker, pulsing, twinkling, breathing, or similar subtle motion as decorative noise if it is visible in the frames.
          </output-boundaries>
        </ui-motion-reference>
        """

    static func generate(template: String, info: CompletionInfo) -> String {
        let effectiveTemplate = template.isEmpty ? defaultTemplate : template

        let replacements: [(String, String)] = [
            ("{{path}}", info.folder?.path ?? ""),
            ("{{frameCount}}", "\(info.frameCount)"),
            ("{{skippedCount}}", "\(info.skippedCount)"),
            ("{{interval}}", String(format: "%.1f", info.interval)),
            ("{{format}}", info.format),
            ("{{changeDetection}}", info.changeDetection ? "on" : "off"),
            ("{{duration}}", ElapsedTimeFormatter.formatTime(info.duration)),
        ]

        var result = effectiveTemplate
        for (placeholder, value) in replacements {
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        return result
    }
}
