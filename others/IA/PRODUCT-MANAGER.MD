# Project Analysis: osx_samourai-project-manager

## Project Summary
A native macOS application providing a rigorous, structured platform for project piloting and delivery management. The core purpose is to enforce the "Samurai" method through strong governance, proactive risk management, and targeted delivery.

## Business Purpose
To minimize project lifecycle risks by maintaining tight control over scope, artifacts, resources, and technical execution through a defined methodology. This system enforces disciplined decision-making to ensure successful project delivery against initial framing.

## Target Users
*   **Project Managers/Leads:** Responsible for overall delivery, risk ownership, and tracking artifacts.
*   **Team Members:** Users involved in inputting data (risks, deliverables) and tracking progress.
*   **Stakeholders:** Parties requiring oversight on project health, resource allocation, and risk exposure.

## Current Technical Stack
*   **Language:** Swift
*   **Framework:** SwiftUI (macOS)
*   **Build System:** Swift Package Manager (SPM, requiring macOS 15+)
*   **Architecture:** Native Application Client

## Probable Constraints (Current)
*   Adherence to the "Samurai" methodology is paramount.
*   Focus on **strong governance** and upfront planning regarding scope and artifacts.
*   The initial delivery is focused on core management tools (risk, resource CRUD) rather than generalized project tracking.

## PM Operating Instructions
*   **Prioritize Method Adherence:** Ensure all features align with the constraints and philosophy of the "Samurai" method.
*   **Data Integrity:** Focus on accurate capture and management of risks, deliverables, and resources.
*   **Traceability:** Maintain clear links between project details, identified risks, and required artifacts.

## Roadmap Guidance
*   **Phase 1 (Current):** Stabilize and perfect the core management loop: Input -> Track -> Mitigate Risk.
*   **Future Expansion:** Focus on enhancing cross-project visibility (e.g., portfolio views) and deeper integration with external workflows.

## Feature Prioritization Method
*   **Strict Governance Filter:** Any proposed feature must demonstrate how it enhances control, mitigates risk, or provides clearer visibility into the project's current state.
*   **Deliverable Alignment:** Features must serve a documented, high-value need defined by the project scope.

## Delivery Rules
*   **Pragmatic/Targeted:** Deliver features in focused, high-impact increments aligned with the "Samurai" method checkpoints.
*   **Data Completeness:** Must support data import/export (`xlsx`, `csv`, `tsv`) to handle real-world inputs.

## Communication Rules
*   All management discussions must be framed around the risk profile and alignment with the project's core goal.

## Definition of Done
*   A feature is done when it has been successfully integrated into the build, documented in the `README.md`, and meets its original use case for controlled project piloting.