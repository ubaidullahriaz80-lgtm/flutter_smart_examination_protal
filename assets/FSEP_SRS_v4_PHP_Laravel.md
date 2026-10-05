**SOFTWARE REQUIREMENT SPECIFICATION**

**Flutter Smart Examination Portal (FSEP)**

Supervisor

**Majid Khawar**

**UNIVERSITY OF SOUTHERN PUNJAB**

Department of Computer Science & IT

Multan

  -----------------------------------------------------------------------
  **Group Member**                         **Registration No.**
  ---------------------------------------- ------------------------------
  Ubaidullah                               BSSE-023R22P-13

  Faisal Ahmad                             BSSE-023R22P-16

  M. Asad Malik                            BSSE-023R22P-18
  -----------------------------------------------------------------------

**Table of Contents**

[**1. Introduction 3**](#heading_100)

> [1.1 Purpose 3](#heading_101)
>
> [1.2 Scope 3](#heading_102)
>
> [1.3 Problem Statement 3](#heading_103)
>
> [1.4 Background and Motivation 4](#heading_104)
>
> [1.5 Project Objectives 4](#heading_105)
>
> [1.6 Definitions, Acronyms, and Abbreviations 4](#heading_106)
>
> [1.7 References 5](#heading_107)
>
> [1.8 Document Overview 5](#heading_108)

[**2. Overall Description 5**](#heading_109)

> [2.1 Background and Product Perspective 5](#heading_110)
>
> [2.2 Product Functions 6](#heading_111)
>
> [2.3 User Classes and Characteristics 6](#heading_112)
>
> [2.3.1 System Administrator 6](#heading_113)
>
> [2.3.2 Institutional Administrator 6](#heading_114)
>
> [2.3.3 Examiner / Instructor 7](#heading_115)
>
> [2.3.4 Live Invigilator 7](#heading_116)
>
> [2.3.5 Candidate / Student 7](#heading_117)
>
> [2.4 Operating Environment 7](#heading_118)
>
> [2.5 Design and Implementation Constraints 7](#heading_119)
>
> [2.6 Assumptions and Dependencies 8](#heading_120)
>
> [2.7 Scope Exclusions 8](#heading_121)

[**3. Baseline System Features 8**](#heading_122)

> [3.1 User Management Module (FR-UM) 8](#heading_123)
>
> [3.2 Exam Administration Module (FR-EA) 9](#heading_124)
>
> [3.3 Question Bank Management Module (FR-QM) 9](#heading_125)
>
> [3.4 Offline-First Exam Delivery Engine (FR-ED) 9](#heading_126)
>
> [3.5 Kiosk and Application Security Lockdown Module (FR-KS)
> 10](#heading_127)
>
> [3.6 Automated Grading Pipeline (FR-AG) 10](#heading_128)
>
> [3.7 Reporting and Institutional Analytics Module (FR-RA)
> 10](#heading_129)
>
> [3.8 Push Notification Integration Module (FR-PN) 10](#heading_130)

[**4. Research-Grade Novelty Modules 11**](#heading_131)

> [4.1 Novelty 1: Behavioral Cheating Detection System (BCD)
> 11](#heading_132)
>
> [4.1.1 Problem Statement 11](#heading_133)
>
> [4.1.2 Research Contribution 11](#heading_134)
>
> [4.1.3 System Architecture Changes 11](#heading_135)
>
> [4.1.4 Risk Score Algorithm 12](#heading_136)
>
> [4.1.5 Functional Requirements 12](#heading_137)
>
> [4.1.6 Non-Functional Requirements 12](#heading_138)
>
> [4.1.7 Database Modifications 13](#heading_139)
>
> [4.1.8 REST API Design 14](#heading_140)
>
> [4.1.9 Flutter Implementation Plan 14](#heading_141)
>
> [4.1.10 Backend Implementation Plan 14](#heading_142)
>
> [4.2 Novelty 2: AI Question Generator from Syllabus (QG)
> 15](#heading_143)
>
> [4.2.1 Problem Statement 15](#heading_144)
>
> [4.2.2 Research Contribution 15](#heading_145)
>
> [4.2.3 AI Generation Workflow 15](#heading_146)
>
> [4.2.4 Prompt Engineering Design 15](#heading_147)
>
> [4.2.5 Functional Requirements 16](#heading_148)
>
> [4.2.6 Non-Functional Requirements 16](#heading_149)
>
> [4.2.7 Database Modifications 17](#heading_150)
>
> [4.2.8 REST API Design 17](#heading_151)
>
> [4.2.9 Flutter Implementation Plan 17](#heading_152)
>
> [4.2.10 Backend Implementation Plan 18](#heading_153)
>
> [4.3 Novelty 3: Learning Gap Detection and Recommendation Engine (LGD)
> 18](#heading_154)
>
> [4.3.1 Problem Statement 18](#heading_155)
>
> [4.3.2 Research Contribution 18](#heading_156)
>
> [4.3.3 Functional Requirements 19](#heading_157)
>
> [4.3.4 Non-Functional Requirements 19](#heading_158)
>
> [4.3.5 Database Modifications 19](#heading_159)
>
> [4.3.6 REST API Design 20](#heading_160)
>
> [4.3.7 Flutter Implementation Plan 20](#heading_161)
>
> [4.3.8 Backend Implementation Plan 21](#heading_162)

[**5. External Interface Requirements 21**](#heading_163)

> [5.1 User Interface 21](#heading_164)
>
> [5.2 Hardware Interface 21](#heading_165)
>
> [5.3 Software Interface 21](#heading_166)
>
> [5.4 Communication Interface 22](#heading_167)

[**6. System Models, UML Diagrams, and Architecture 22**](#heading_168)

> [6.1 System Use Case Summary Diagram 22](#heading_169)
>
> [6.2 Updated Technical Domain Class Diagram 23](#heading_170)
>
> [6.3 Behavior-Monitored Exam Session Sequence Diagram
> 24](#heading_171)
>
> [6.4 Learning Gap Detection Post-Exam Activity Diagram
> 25](#heading_172)
>
> [6.5 Integrated System Architecture 26](#heading_173)
>
> [6.6 Database Entity Relationship Diagram (ERD) 27](#heading_174)

[**7. Non-Functional Requirements 28**](#heading_175)

[**8. Conclusion 28**](#heading_176)

[**Appendix A: Glossary of Additional Terms 29**](#heading_177)

[**Appendix B: Consolidated API Endpoint Reference 30**](#heading_178)

[**Appendix C: Test Case Traceability Matrix 31**](#heading_179)

[**Appendix D: Bibliography and References 31**](#heading_180)

> [D.1 Standards and Guidelines 31](#heading_181)
>
> [D.2 Technical Documentation 32](#heading_182)
>
> [D.3 Research References 32](#heading_183)

[**Appendix E: Document Revision History 32**](#heading_184)

[]{#heading_100 .anchor}**1. Introduction**

[]{#heading_101 .anchor}**1.1 Purpose**

This document is the Software Requirement Specification (SRS) for the
Flutter Smart Examination Portal (FSEP), an AI-augmented, cross-platform
assessment ecosystem developed as a Final Year Project for the
Department of Computer Science and Information Technology at the
University of Southern Punjab, Multan. It formally defines the
functional and non-functional requirements of the proposed system and
serves as the primary reference for the design, development, and
evaluation of the platform.

This document is addressed to the project supervisor, the academic
evaluation committee, and the development team. It provides a
comprehensive, unambiguous description of the system\'s capabilities,
interfaces, constraints, and quality attributes, ensuring that all
stakeholders share a common understanding of what the system will do and
how it will behave.

[]{#heading_102 .anchor}**1.2 Scope**

FSEP is a cross-platform client-server examination ecosystem compiled
natively for Android, iOS, Windows, macOS, Linux, and Web from a single
Flutter/Dart codebase, engineered to facilitate high-stakes
institutional assessments under both intermittent and zero-bandwidth
network scenarios. The baseline platform provides identity and access
management, exam administration, a tagged question bank, offline-first
encrypted exam delivery, kiosk-mode security, automated grading,
institutional analytics, and push notifications.

This specification extends that baseline with three research-grade
novelties that are the principal subject of this revision:

-   **Behavioral Cheating Detection System** --- scores session
    integrity risk from interaction telemetry without continuous webcam
    monitoring.

-   **AI Question Generator from Syllabus** --- produces MCQ,
    True/False, Short Answer, and Coding questions from uploaded syllabi
    and lecture notes, subject to mandatory human approval.

-   **Learning Gap Detection & Recommendation Engine** --- converts
    results into topic-level mastery scores, Bloom\'s Taxonomy
    breakdowns, and a personalized improvement roadmap.

The backend is a centralized PHP Laravel API layer backed by PostgreSQL,
now augmented with a dedicated AI Services layer, a Behavioral Integrity
Service, and a Learning Analytics Service.

[]{#heading_103 .anchor}**1.3 Problem Statement**

Conventional digital examination platforms rely on continuous
webcam/video proctoring that is bandwidth-heavy, costly to review, and
invasive of student privacy; require instructors to manually author
every question bank entry; and leave learning gaps completely
undiagnosed once a result is published. These three gaps are the
specific research and engineering problems this SRS addresses through
the three novelty modules introduced in Section 4.

[]{#heading_104 .anchor}**1.4 Background and Motivation**

Behavioral-analytics proctoring, derived from response-timing analysis,
focus-loss detection, and navigation-pattern monitoring, has emerged as
a materially lighter-weight alternative to constant video proctoring,
reducing both bandwidth requirements and the privacy burden on students.
The recent maturity of large language models has made automatic,
syllabus-grounded question generation practical even for
resource-constrained institutions. Learning-analytics dashboards built
on Bloom\'s Taxonomy give students a concrete, actionable path to
improvement.

[]{#heading_105 .anchor}**1.5 Project Objectives**

-   To design and implement a behavioral risk-scoring pipeline that
    flags suspicious in-session activity from interaction telemetry
    alone, without continuous video or audio capture.

-   To build an AI-assisted, human-in-the-loop question-generation
    workflow that converts uploaded syllabus documents into a
    teacher-reviewed, taxonomy-tagged question bank.

-   To design a post-exam analytics engine that maps incorrect responses
    to weak topics, Bloom\'s Taxonomy levels, and difficulty bands, and
    produces a personalized improvement roadmap.

-   To document the full IEEE 830 / ISO 29148-aligned technical
    specification for every novelty so that each can be implemented
    directly from this SRS.

[]{#heading_106 .anchor}**1.6 Definitions, Acronyms, and Abbreviations**

  -----------------------------------------------------------------------
  **Term**         **Definition**
  ---------------- ------------------------------------------------------
  FSEP             Flutter Smart Examination Portal --- the system
                   defined by this SRS.

  JWT              JSON Web Token used for stateless session
                   authentication.

  RBAC             Role-Based Access Control.

  MFA              Multi-Factor Authentication.

  SQLite /         Embedded relational storage and its AES-256
  SQLCipher        transparent encryption extension.

  FCM              Firebase Cloud Messaging --- cross-platform push
                   notification transport.

  BLoC             Business Logic Component --- the Flutter
                   state-management architecture pattern.

  Risk Score       A 0--100 composite integrity score produced by the
                   Behavioral Cheating Detection System (Novelty 1).

  Bloom\'s         Hierarchical cognitive classification: Remember,
  Taxonomy         Understand, Apply, Analyze, Evaluate, Create (Novelty
                   3).

  KPI              Key Performance Indicator.

  ERD              Entity Relationship Diagram.

  Laravel          PHP web application framework providing the REST API,
                   service layer, and queue system for the FSEP backend.
  -----------------------------------------------------------------------

[]{#heading_107 .anchor}**1.7 References**

-   IEEE Std 830-1998 --- IEEE Recommended Practice for Software
    Requirements Specifications.

-   ISO/IEC/IEEE 29148:2018 --- Systems and Software Engineering:
    Requirements Engineering.

-   Google Flutter and Dart Framework Documentation
    (https://docs.flutter.dev).

-   Firebase Cloud Messaging Documentation
    (https://firebase.google.com/docs).

-   Laravel Framework Documentation (https://laravel.com/docs).

-   OWASP Mobile Application Security Verification Standard (MASVS).

-   European Union General Data Protection Regulation (GDPR) 2016/679.

-   Anderson, L. W., & Krathwohl, D. R. (2001). A Taxonomy for Learning,
    Teaching, and Assessing. Longman.

[]{#heading_108 .anchor}**1.8 Document Overview**

This specification is organized into eight main sections plus
appendices. Section 1 provides the introduction, scope, problem
statement, background, objectives, and terminology. Section 2 gives an
overall description including a comparative survey of existing
examination platforms, product functions, user classes, and constraints.
Section 3 specifies the eight baseline functional modules. Section 4
specifies the three research-grade novelty modules in full
implementation-ready detail. Section 5 establishes external interface
requirements. Section 6 presents UML models and the integrated
architecture. Section 7 consolidates non-functional requirements.
Section 8 concludes the document. Appendices A--E supply the glossary,
API reference, test case traceability, bibliography, and revision
history.

[]{#heading_109 .anchor}**2. Overall Description**

[]{#heading_110 .anchor}**2.1 Background and Product Perspective**

FSEP operates as an intelligent, secure, distributed software ecosystem
composed of a highly scalable centralized backend REST API architecture
and uniform native multiplatform client applications. Management setups,
question pools, and analysis dashboards execute within optimized web
dashboards or admin desktop frames, while the actual student exam
delivery client runs natively inside sandboxed mobile, tablet, or
workstation contexts.

With the addition of the three novelty modules described in this revised
specification, the system extends its baseline assessment engine into a
fully behaviorally-monitored, AI-assisted, and learning-aware
examination platform. Each novelty integrates as a distinct Laravel
module on the backend and a dedicated BLoC module on the Flutter client,
preserving the platform\'s offline-first and modular design principles.

[]{#heading_111 .anchor}**2.2 Product Functions**

At a high level, the platform provides the following core capability
domains:

-   **Identity and Profile Access Management**: JWT-based session
    authorization, hardware biometric MFA, and RBAC across five user
    roles.

-   **Exam Administration and Scheduling**: full exam lifecycle
    management with platform-targeted visibility and offline
    pre-caching.

-   **Question Bank Engineering**: multi-format, taxonomy-tagged
    question authoring with AI-assisted generation (Novelty 2).

-   **Offline Exam Delivery**: zero-connectivity exam sessions with
    local encrypted storage and background sync.

-   **Behavioral Integrity Monitoring**: session telemetry collection,
    risk scoring, and live invigilator alerts (Novelty 1).

-   **Automated and Sandboxed Grading**: server-side objective grading,
    keyword-regex short-answer evaluation, and Docker-isolated code
    execution.

-   **Learning Gap Detection and Recommendations**: post-exam analytics
    producing topic mastery scores, Bloom\'s breakdowns, and improvement
    roadmaps (Novelty 3).

-   **Institutional Analytics and Reporting**: cohort-level performance
    dashboards, PDF/Excel export.

-   **Push Notification Relay**: pre-exam reminders, result alerts, and
    sync confirmation via FCM and native OS daemons.

[]{#heading_112 .anchor}**2.3 User Classes and Characteristics**

[]{#heading_113 .anchor}**2.3.1 System Administrator**

Profile Match: Senior IT infrastructure architects, DevOps specialists,
and database security officers. Technical Competency: Expert. Functional
Responsibility: Directs production infrastructure initialization,
manages security keys, monitors cluster instances, and handles
enterprise deployment configurations.

[]{#heading_114 .anchor}**2.3.2 Institutional Administrator**

Profile Match: University registrars, academic department heads, and
scheduling officers. Technical Competency: Moderate. Functional
Responsibility: Provisions user credentials, manages organizational
tracks, and reviews multi-department audit logs.

[]{#heading_115 .anchor}**2.3.3 Examiner / Instructor**

Profile Match: Faculty professors, course lecturers, and certified
evaluators. Technical Competency: Light. Functional Responsibility:
Designs and reviews AI-generated questions, assigns assessment
parameters, monitors live behavioral risk dashboards during active
exams, and reviews learning gap reports post-exam.

[]{#heading_116 .anchor}**2.3.4 Live Invigilator**

Profile Match: Designated proctoring personnel assigned to monitor
active examination sessions. Technical Competency: Basic. Functional
Responsibility: Monitors the live behavioral risk dashboard, reviews
flagged suspicious events, and escalates or dismisses alerts in real
time.

[]{#heading_117 .anchor}**2.3.5 Candidate / Student**

Profile Match: Enrolled learners and professional test-takers. Technical
Competency: Basic. Functional Responsibility: Authenticates via
biometric checks, opens scheduled exams, interacts with question
layouts, and reviews learning gap reports and improvement roadmaps.

[]{#heading_118 .anchor}**2.4 Operating Environment**

The cross-platform native client suite maintains verified operation
across: Android 6.0+ (API 23, min 2 GB RAM), iOS 12.0+, Windows 10 x64,
macOS 10.14+, Linux Ubuntu 20.04+ LTS, and Web (Chrome 88+, Firefox
85+), each requiring minimum 4 GB RAM except Android. The backend API
runs on Ubuntu Server 20.04+/22.04 LTS with 8 GB RAM minimum in a
containerized PHP Laravel environment. Central storage requires
PostgreSQL v15+ with 8 GB RAM. The AI Services layer requires an
additional containerized Python microservice with GPU-optional inference
capability.

[]{#heading_119 .anchor}**2.5 Design and Implementation Constraints**

-   **Codebase Uniformity**: Development teams must enforce a single,
    unified Flutter/Dart source repository; branching into separate
    platform-specific logic trees is strictly prohibited.

-   **State Isolation**: The application must use the BLoC pattern to
    separate user state changes from UI presentation logic.

-   **Data Path Security**: All communication must go over encrypted
    HTTPS (TLS 1.3).

-   **AI Question Approval Gate**: No AI-generated question may reach a
    live exam session without an explicit teacher approval action;
    questions remain in PENDING_REVIEW status until approved.

-   **Behavioral Telemetry Granularity**: Event telemetry must be
    persisted locally to SQLite at sub-second resolution during offline
    exam sessions and flushed to the server upon reconnection.

[]{#heading_120 .anchor}**2.6 Assumptions and Dependencies**

-   Candidate devices meet the hardware baseline specified in Section
    2.4.

-   Educational organizations are solely responsible for signing,
    provisioning, and distributing compiled installation files.

-   Offline assessment sessions are capped at a maximum of 72 continuous
    hours without server communication.

-   The AI question generation service depends on access to the
    Anthropic Claude API or a locally hosted open-weights model; the
    system gracefully degrades to manual-only question authoring if
    unavailable.

-   Behavioral telemetry processing for the risk score does not
    constitute legal evidence of academic misconduct without independent
    invigilator review.

[]{#heading_121 .anchor}**2.7 Scope Exclusions**

-   Continuous webcam video capture or real-time face-recognition
    proctoring.

-   Integration with third-party LMS platforms such as Moodle or
    Blackboard.

-   Live online payment processing or fee management.

-   Native iOS or Android mobile application development outside the
    Flutter framework.

[]{#heading_122 .anchor}**3. Baseline System Features**

This section specifies the eight functional modules that form the core
capability foundation of FSEP, carried forward and extended from the
original platform design. The three research-grade novelty modules are
specified in full detail in Section 4.

[]{#heading_123 .anchor}**3.1 User Management Module (FR-UM)**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-UM-01    The system shall allow users to register with an email
              address and password. Institutional Administrators shall
              have access to bulk-creation functions via CSV import.

  FR-UM-02    System access shall be restricted via short-lived JWT
              handshakes with an 8-hour expiration limit. The frontend
              app shall access native device enclaves for biometric
              secondary verification.

  FR-UM-03    Security policies shall implement strict RBAC, mapping
              users into defined levels: System Administrator,
              Institutional Administrator, Examiner, Live Invigilator, or
              Candidate.

  FR-UM-04    Shifts in user configuration preferences, layout modes,
              notification options, and profile avatars shall sync across
              active devices immediately upon successful server
              connection.
  -----------------------------------------------------------------------

[]{#heading_124 .anchor}**3.2 Exam Administration Module (FR-EA)**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-EA-01    Examiners shall configure: unique alpha-numeric title,
              descriptive text, duration, maximum marks, negative marking
              weights, random question ordering, and choice shuffling.

  FR-EA-02    The creator platform shall provide explicit operating
              target checkboxes restricting exam visibility to specified
              platforms. Unauthorized platforms shall hide restricted
              exam profiles automatically.

  FR-EA-03    Instructors shall toggle an offline-ready flag per exam.
              Client apps shall automatically pre-cache all question
              models, assets, and schema mappings into local SQLite
              storage when connectivity is available.

  FR-EA-04    Examiners shall enable Behavioral Integrity Monitoring per
              exam, activating the telemetry capture and risk-scoring
              pipeline defined in FR-BCD-01 through FR-BCD-07 (Novelty
              1).
  -----------------------------------------------------------------------

[]{#heading_125 .anchor}**3.3 Question Bank Management Module (FR-QM)**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-QM-01    The question designer shall support: MCQ, True/False, Short
              Answer, Essay, Matching, and Code Snippet question types.

  FR-QM-02    Every question entry shall include: course code label,
              difficulty scale (Easy, Medium, Hard), Bloom\'s Taxonomy
              category flag, and an is_ai_generated provenance flag.

  FR-QM-03    AI-generated questions (Novelty 2) shall remain in
              PENDING_REVIEW status and shall not be eligible for exam
              assignment until an Examiner explicitly approves them.
  -----------------------------------------------------------------------

[]{#heading_126 .anchor}**3.4 Offline-First Exam Delivery Engine
(FR-ED)**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-ED-01    Active test instances shall execute completely independent
              of network availability, loading question elements from the
              encrypted local SQLite storage without relying on external
              servers.

  FR-ED-02    Upon identifying a stable network connection, the
              background sync engine shall automatically stream unsynced
              student entries to the server via transactional batch
              endpoints with conflict resolution.

  FR-ED-03    If the client crashes or the device loses power, the system
              shall restore the exact session configuration recorded
              prior to the interruption, including current question
              position and answered-state.

  FR-ED-04    Behavioral telemetry events (Novelty 1) shall be persisted
              locally to the BehavioralEvent SQLite table during offline
              sessions and flushed to the server upon reconnection.
  -----------------------------------------------------------------------

[]{#heading_127 .anchor}**3.5 Kiosk and Application Security Lockdown
Module (FR-KS)**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-KS-01    On Windows, macOS, and Linux, the client shall transition
              to fullscreen kiosk mode, blocking clipboard access,
              right-click menus, and multitasking key combinations.

  FR-KS-02    On Android and iOS, the application shall engage Screen
              Pinning (Android) and Guided Access (iOS) via native
              platform channel integration layers.

  FR-KS-03    The kiosk subsystem shall additionally hook focus-loss
              events to generate FocusLoss behavioral telemetry entries
              consumed by the Behavioral Cheating Detection Service
              (Novelty 1).
  -----------------------------------------------------------------------

[]{#heading_128 .anchor}**3.6 Automated Grading Pipeline (FR-AG)**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-AG-01    MCQ and True/False items shall be scored on the server
              within 5 seconds of submission. Scores shall write to
              PostgreSQL, stream to client SQLite, and trigger FCM push
              alerts.

  FR-AG-02    Short-text responses shall be evaluated using regex rules
              and keyword matching lists compiled by the examiner;
              unmatched responses route to a manual grading queue.

  FR-AG-03    Code-frame responses shall be processed in isolated Docker
              environments; the engine compiles the code and tests it
              against predefined unit criteria, outputting scoring
              vectors, runtime traces, and pass/fail indicators.

  FR-AG-04    Upon final grading completion, the Automated Grading
              Pipeline shall trigger the Learning Gap Detection service
              (Novelty 3).
  -----------------------------------------------------------------------

[]{#heading_129 .anchor}**3.7 Reporting and Institutional Analytics
Module (FR-RA)**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-RA-01    Student views shall display: individual item correctness
              states, point distributions, global cohort percentile
              standing, final pass/fail, and a link to their Learning Gap
              Report (Novelty 3).

  FR-RA-02    High-tier administrators shall access cohort performance
              trends, completion rates, median completion times, device
              reliability metrics, and behavioral risk score
              distributions (Novelty 1).

  FR-RA-03    Instructors shall export assessment outputs and learning
              gap summaries into PDF and Excel formats from native
              desktop clients and web management systems.
  -----------------------------------------------------------------------

[]{#heading_130 .anchor}**3.8 Push Notification Integration Module
(FR-PN)**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-PN-01    The system shall trigger push reminders to scheduled
              candidates at 24 hours and 1 hour before an exam session
              begins, delivered via FCM (mobile) and native OS alerts
              (desktop).

  FR-PN-02    When examiners publish final evaluations, a push alert
              shall deliver a summarized overview including the
              candidate\'s score and a link to the Learning Gap Report
              (Novelty 3) to the student\'s device.

  FR-PN-03    When the background sync engine successfully pushes offline
              data to the server, the application shall display a local
              device notification confirming successful data sync.
  -----------------------------------------------------------------------

[]{#heading_131 .anchor}**4. Research-Grade Novelty Modules**

This section specifies in full IEEE SRS style the three research-grade
novelty modules that extend the FSEP baseline. Each subsection provides:
problem statement, research contribution, architecture changes,
functional requirements, non-functional requirements, database
modifications, REST API design, UML update summary, and Flutter and
backend implementation plan.

[]{#heading_132 .anchor}**4.1 Novelty 1: Behavioral Cheating Detection
System (BCD)**

[]{#heading_133 .anchor}**4.1.1 Problem Statement**

Video-based proctoring is the dominant integrity mechanism in digital
examinations but imposes prohibitive bandwidth costs, requires reliable
front-facing cameras on every candidate device, demands hours of manual
video review per exam, and raises significant privacy concerns.
Behavioral telemetry --- derived from interaction timing, navigation
patterns, and focus events --- offers a materially lighter-weight
integrity signal that is collected automatically during normal exam
operation with no additional hardware.

[]{#heading_134 .anchor}**4.1.2 Research Contribution**

This novelty designs and integrates a multi-signal behavioral risk
scoring engine that synthesizes seven event categories into a single
0--100 Risk Score using a weighted additive model. The engine operates
entirely from existing interaction streams --- answer changes, question
navigation, response timing, tab-switch attempts, window focus loss,
idle periods, and device-change events --- without any camera feed. The
live invigilator dashboard streams risk deltas in near-real-time,
allowing targeted human intervention rather than blanket video review.

[]{#heading_135 .anchor}**4.1.3 System Architecture Changes**

A new BehavioralTelemetryService Dart class is added to the Flutter
client. It attaches event hooks to the ExamScreen\'s FocusNode,
WidgetsBindingObserver, and NavigationEvent streams. Captured events are
written synchronously to the local SQLite behavioral_events table and
queued for server sync. On the backend, a new Laravel Behavioral Service
Module computes the Risk Score after each telemetry batch and publishes
updates to the InvigilatorDashboard via Server-Sent Events (SSE).

[]{#heading_136 .anchor}**4.1.4 Risk Score Algorithm**

Risk Score RS is computed as: RS = min(100, Σ w_i × f_i(event_count_i)),
where w_i is the weight assigned to event category i and f_i is a
logarithmic dampening function to prevent any single event type from
saturating the score. Default weights: RapidAnswerChange = 15,
ExcessiveQuestionSwitch = 12, UnusualSpeed (\< 3 s/item) = 10,
TabSwitchAttempt = 20, WindowFocusLoss = 18, IdlePeriod (\> 120 s) = 8,
DeviceChange = 25. Thresholds: RS 0--30 = Low, 31--60 = Medium, 61--80 =
High, 81--100 = Critical.

[]{#heading_137 .anchor}**4.1.5 Functional Requirements**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-BCD-01   Event Capture: The client shall capture and locally persist
              the following event types during every exam session:
              RapidAnswerChange, ExcessiveQuestionSwitch,
              UnusualAnsweringSpeed, TabSwitchAttempt, WindowFocusLoss,
              IdlePeriod, DeviceChange.

  FR-BCD-02   Risk Score Computation: The Behavioral Service Module shall
              compute a Risk Score (0--100) using the weighted additive
              algorithm defined in Section 4.1.4 after each telemetry
              batch received from the client.

  FR-BCD-03   Suspicious Event Logging: Every flagged event shall be
              persisted in the behavioral_events PostgreSQL table with
              session_id, event_type, severity, timestamp, and contextual
              metadata.

  FR-BCD-04   Live Invigilator Dashboard: The InvigilatorDashboard screen
              shall display, per candidate, the current Risk Score, a
              colored risk band indicator, and a timestamped event log;
              updates shall arrive within 5 seconds of event capture.

  FR-BCD-05   Alert Generation: When a candidate\'s Risk Score crosses 60
              (High threshold), the system shall generate an in-dashboard
              alert and send an FCM push notification to the assigned
              invigilator.

  FR-BCD-06   Offline Telemetry Persistence: All behavioral events shall
              be written synchronously to local SQLite during offline
              sessions and flushed as a batch to the Behavioral Service
              Module upon network restoration.

  FR-BCD-07   Invigilator Action Log: Invigilators shall be able to mark
              a flagged event as Reviewed, Escalated, or Dismissed; each
              action shall be timestamped and stored in
              behavioral_review_actions.
  -----------------------------------------------------------------------

[]{#heading_138 .anchor}**4.1.6 Non-Functional Requirements**

  ------------------------------------------------------------------------
  **Req. ID**  **Functional / Quality Requirement**
  ------------ -----------------------------------------------------------
  NFR-BCD-01   Latency: Server-side Risk Score recomputation shall
               complete within 200 milliseconds of receiving a telemetry
               batch. Dashboard SSE updates shall arrive at the
               invigilator browser within 5 seconds of the triggering
               event.

  NFR-BCD-02   Storage: The local SQLite behavioral_events table shall
               support 10,000 event rows per session without latency
               degradation on the minimum-specification device baseline.

  NFR-BCD-03   Privacy: Behavioral telemetry data shall be stored
               encrypted (SQLCipher on client, AES-256 at rest on server)
               and shall not be accessible to the candidate. Retention of
               raw telemetry shall not exceed 90 days post-exam per GDPR
               guidance.

  NFR-BCD-04   False Positive Rate: In controlled benchmark scenarios, the
               Risk Score shall not classify more than 10% of known-clean
               sessions above the Medium threshold (RS \> 30).
  ------------------------------------------------------------------------

[]{#heading_139 .anchor}**4.1.7 Database Modifications**

**Table: behavioral_events**

  ------------------------------------------------------------------------------
  **Attribute**     **Data      **Key**   **References / Notes**
                    Type**                
  ----------------- ----------- --------- --------------------------------------
  id                UUID        PK        

  session_id        UUID        FK        exam_sessions.id

  candidate_id      UUID        FK        users.id

  event_type        ENUM                  RapidAnswerChange \| ExcessiveSwitch
                                          \| UnusualSpeed \| TabSwitch \|
                                          FocusLoss \| IdlePeriod \|
                                          DeviceChange

  severity          ENUM                  LOW \| MEDIUM \| HIGH \| CRITICAL

  event_timestamp   TIMESTAMP             Client-side timestamp

  metadata          JSONB                 Contextual payload (e.g., question_id,
                                          time_spent_ms)

  is_synced         BOOLEAN               False while stored only in local
                                          SQLite
  ------------------------------------------------------------------------------

**Table: behavioral_risk_scores**

  ------------------------------------------------------------------------------
  **Attribute**     **Data      **Key**   **References / Notes**
                    Type**                
  ----------------- ----------- --------- --------------------------------------
  id                UUID        PK        

  session_id        UUID        FK        exam_sessions.id

  risk_score        INT                   0--100 composite score

  risk_band         ENUM                  Low \| Medium \| High \| Critical

  computed_at       TIMESTAMP             

  event_breakdown   JSONB                 Per-category contribution to total
                                          score
  ------------------------------------------------------------------------------

**Table: behavioral_review_actions**

  -----------------------------------------------------------------------------
  **Attribute**    **Data      **Key**   **References / Notes**
                   Type**                
  ---------------- ----------- --------- --------------------------------------
  id               UUID        PK        

  event_id         UUID        FK        behavioral_events.id

  invigilator_id   UUID        FK        users.id

  action           ENUM                  Reviewed \| Escalated \| Dismissed

  note             TEXT                  Optional invigilator comment

  actioned_at      TIMESTAMP             
  -----------------------------------------------------------------------------

[]{#heading_140 .anchor}**4.1.8 REST API Design**

  ---------------------------------------------------------------------------------------------
  **Method**   **Endpoint**                         **Request**           **Response**
  ------------ ------------------------------------ --------------------- ---------------------
  POST         /api/behavioral/events/batch         { session_id, events: { risk_score,
                                                    \[{ type, ts, meta    risk_band, alerts\[\]
                                                    }\] }                 }

  GET          /api/behavioral/dashboard/:exam_id   Bearer JWT            SSE stream: {
                                                    (Invigilator)         candidate_id,
                                                                          risk_score,
                                                                          risk_band,
                                                                          latest_events\[\] }

  GET          /api/behavioral/report/:session_id   Bearer JWT (Examiner) { events\[\],
                                                                          risk_score,
                                                                          risk_band,
                                                                          review_actions\[\] }

  POST         /api/behavioral/review               { event_id, action,   { status:
                                                    note }                \'recorded\', action
                                                                          }

  GET          /api/behavioral/alerts/:exam_id      Bearer JWT            { alerts: \[{
                                                    (Invigilator)         candidate_id,
                                                                          risk_score,
                                                                          triggered_at }\] }
  ---------------------------------------------------------------------------------------------

[]{#heading_141 .anchor}**4.1.9 Flutter Implementation Plan**

-   New Service: BehavioralTelemetryService --- attaches to ExamScreen
    lifecycle, writes events to SQLite via BehavioralRepository.

-   New BLoC: BehavioralBloc --- events: RecordEvent, SyncBatch,
    ClearSession; states: BehavioralIdle, BehavioralSyncing,
    BehavioralBatchSynced.

-   New Screen: InvigilatorDashboardScreen --- SSE listener,
    per-candidate risk tiles with color-coded band, event log drawer.

-   Model classes: BehavioralEvent, RiskScore, ReviewAction.

-   Kiosk module extension: FocusMonitor hooks focus-loss events into
    BehavioralTelemetryService.

[]{#heading_142 .anchor}**4.1.10 Backend Implementation Plan**

-   Laravel Module: app/Modules/Behavioral/ ---
    BehavioralController.php, BehavioralService.php,
    RiskScoreEngine.php.

-   RiskScoreEngine.php: implements the weighted additive Risk Score
    model and logarithmic dampening function defined in Section 4.1.4.

-   PostgreSQL: new tables behavioral_events, behavioral_risk_scores,
    and behavioral_review_actions (schemas above); index on (session_id,
    candidate_id).

-   Laravel Queue System: telemetry batches are dispatched to a queued
    job for asynchronous risk-score recomputation, keeping the
    synchronous API response fast.

-   Broadcast layer: Laravel Server-Sent Events route streams risk-score
    deltas to the InvigilatorDashboard in near-real-time.

[]{#heading_143 .anchor}**4.2 Novelty 2: AI Question Generator from
Syllabus (QG)**

[]{#heading_144 .anchor}**4.2.1 Problem Statement**

Manual question bank authoring is time-intensive, limits the size of
available item pools, and creates a risk of question exposure through
re-use across cohorts. Instructors in resource-constrained institutions
often reuse the same limited question sets across multiple semesters,
undermining assessment integrity. Large language models now provide a
practical mechanism for generating contextually grounded questions
directly from curriculum source materials, subject to mandatory human
review to ensure pedagogical quality.

[]{#heading_145 .anchor}**4.2.2 Research Contribution**

This novelty implements a complete human-in-the-loop AI question
generation pipeline within FSEP. Instructors upload PDF or text syllabus
documents; the system extracts text, segments it into topic chunks, and
dispatches structured prompts to the AI backend to generate MCQ,
True/False, Short Answer, and Coding questions with automatic Bloom\'s
Taxonomy level suggestions and difficulty estimates. Generated items are
quarantined in a PENDING_REVIEW status and cannot reach live exams until
an Examiner explicitly approves them.

[]{#heading_146 .anchor}**4.2.3 AI Generation Workflow**

1.  Instructor uploads PDF/TXT syllabus or lecture notes via the
    QuestionGeneratorScreen.

2.  DocumentParserService extracts text and segments it into topic
    chunks of 500--1000 tokens.

3.  For each chunk, the Laravel PromptEngineeringService assembles a
    structured prompt (see Section 4.2.4) and dispatches it to the AI
    API endpoint via a queued job.

4.  The AI API returns a JSON array of candidate questions. The system
    parses, validates, and stores each as a Question record with status
    = PENDING_REVIEW.

5.  The Examiner opens the AIQuestionReviewScreen, inspects each
    generated question, edits as needed, and clicks Approve or Reject.

6.  Approved questions receive status = APPROVED and become eligible for
    exam assignment. Rejected questions are archived with rejection
    reason.

[]{#heading_147 .anchor}**4.2.4 Prompt Engineering Design**

System prompt template: "You are an expert academic question author.
Given the following course content excerpt, generate {n} questions of
type {type} at Bloom\'s Taxonomy level {bloom_level} and difficulty
{difficulty}. For each question output strictly valid JSON conforming to
the schema: { question_text, type, options (if MCQ), correct_answer,
explanation, bloom_level, difficulty, topic_tag }. Output only the JSON
array, no preamble or markdown fences."

Variable injection at runtime: type ∈ {MCQ, TrueFalse, ShortAnswer,
Coding}; bloom_level ∈ {Remember, Understand, Apply, Analyze, Evaluate,
Create}; difficulty ∈ {Easy, Medium, Hard}; n = configurable (default 5
per chunk).

[]{#heading_148 .anchor}**4.2.5 Functional Requirements**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-QG-01    Document Upload: The system shall accept PDF and plain-text
              document uploads of up to 20 MB per file via the instructor
              portal. Multi-file batch upload of up to 10 documents per
              generation job shall be supported.

  FR-QG-02    Text Extraction and Chunking: The DocumentParserService
              shall extract text from uploaded PDFs and segment it into
              topic chunks of 500--1000 tokens with 10% overlap to
              preserve context across boundaries.

  FR-QG-03    AI Generation Request: For each chunk, the system shall
              dispatch a structured prompt to the configured AI API and
              receive a JSON array of candidate question objects
              conforming to the defined schema.

  FR-QG-04    Question Type Coverage: Each generation job shall produce
              at least one question of each supported type (MCQ,
              True/False, Short Answer, Coding) when the source content
              is sufficient to support it.

  FR-QG-05    PENDING_REVIEW Quarantine: All AI-generated questions shall
              be stored with status = PENDING_REVIEW and the
              is_ai_generated = true flag. They shall be invisible to
              exam-assignment workflows until approved.

  FR-QG-06    Human Approval Interface: The AIQuestionReviewScreen shall
              display each pending question with its generated text,
              answer options, AI-suggested Bloom level and difficulty,
              and allow the Examiner to Edit, Approve, or Reject each
              item individually.

  FR-QG-07    Rejection Audit Trail: Rejected questions shall be archived
              with the Examiner\'s user_id, rejection_reason, and
              timestamp in the ai_question_generation_jobs table.

  FR-QG-08    Batch Approval: Examiners shall be able to bulk-approve all
              pending questions within a generation job with a single
              confirmation action, subject to a per-batch review warning.

  FR-QG-09    Generation Job Status Tracking: The system shall track each
              generation job through states: UPLOADING → PARSING →
              GENERATING → REVIEW_PENDING → COMPLETED \| FAILED, with
              per-state timestamps.
  -----------------------------------------------------------------------

[]{#heading_149 .anchor}**4.2.6 Non-Functional Requirements**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  NFR-QG-01   Performance: A 10-page PDF syllabus document shall complete
              text extraction, chunking, AI generation, and database
              storage within 90 seconds under normal server load.

  NFR-QG-02   Quality Gate: The system shall enforce a server-side JSON
              schema validator on every AI response; malformed or
              incomplete question objects shall be discarded and logged;
              the generation job shall continue with valid items.

  NFR-QG-03   Availability Degradation: If the AI API endpoint is
              unavailable, the generation job shall fail gracefully with
              status = FAILED and a user-facing error message; the
              platform shall continue operating in manual-only question
              authoring mode without service interruption.

  NFR-QG-04   Data Privacy: Uploaded syllabus documents shall not be
              forwarded to the AI API in their entirety; only extracted
              text chunks shall be transmitted. Document files shall be
              deleted from server storage within 24 hours of job
              completion.
  -----------------------------------------------------------------------

[]{#heading_150 .anchor}**4.2.7 Database Modifications**

**Table: ai_question_generation_jobs**

  -------------------------------------------------------------------------------------
  **Attribute**         **Data Type**  **Key**   **References / Notes**
  --------------------- -------------- --------- --------------------------------------
  id                    UUID           PK        

  examiner_id           UUID           FK        users.id

  document_name         VARCHAR(255)             Original uploaded filename

  status                ENUM                     UPLOADING \| PARSING \| GENERATING \|
                                                 REVIEW_PENDING \| COMPLETED \| FAILED

  questions_generated   INT                      Count of AI-generated question objects
                                                 returned

  questions_approved    INT                      Count approved by Examiner

  questions_rejected    INT                      Count rejected

  created_at            TIMESTAMP                

  completed_at          TIMESTAMP                
  -------------------------------------------------------------------------------------

The existing QUESTION table is extended with: is_ai_generated BOOLEAN
DEFAULT false; generation_job_id UUID FK ai_question_generation_jobs.id;
review_status ENUM (PENDING_REVIEW \| APPROVED \| REJECTED); reviewed_by
UUID FK users.id; reviewed_at TIMESTAMP; rejection_reason TEXT.

[]{#heading_151 .anchor}**4.2.8 REST API Design**

  -----------------------------------------------------------------------------------------------------------
  **Method**   **Endpoint**                             **Request**                **Response**
  ------------ ---------------------------------------- -------------------------- --------------------------
  POST         /api/questions/generate/upload           multipart/form-data: file, { job_id, status:
                                                        type\[\],                  \'PARSING\' }
                                                        bloom_levels\[\],          
                                                        difficulty                 

  GET          /api/questions/generate/job/:job_id      Bearer JWT (Examiner)      { status,
                                                                                   questions_generated,
                                                                                   questions_pending_review }

  GET          /api/questions/generate/review/:job_id   Bearer JWT (Examiner)      { pending_questions\[\] }

  POST         /api/questions/generate/approve          { question_ids\[\],        { approved_count,
                                                        action:                    rejected_count }
                                                        \'approve\'\|\'reject\',   
                                                        rejection_reason? }        

  DELETE       /api/questions/generate/job/:job_id      Bearer JWT (Examiner)      { status:
                                                                                   \'job_cancelled\' }
  -----------------------------------------------------------------------------------------------------------

[]{#heading_152 .anchor}**4.2.9 Flutter Implementation Plan**

-   New Screen: QuestionGeneratorScreen --- document upload form with
    type/Bloom-level/difficulty configuration.

-   New BLoC: QuestionGenerationBloc --- events: UploadDocument,
    PollJobStatus, ApproveQuestions, RejectQuestion; states:
    GenerationUploading, GenerationInProgress, GenerationReviewReady,
    GenerationComplete.

-   New Screen: AIQuestionReviewScreen --- per-question card with Edit,
    Approve, and Reject actions and a batch-approve banner.

-   Model classes: GenerationJob, GeneratedQuestion.

-   Repository: QuestionGenerationRepository --- handles multipart
    upload and job-status polling against the Laravel API.

[]{#heading_153 .anchor}**4.2.10 Backend Implementation Plan**

-   Laravel Module: app/Modules/QuestionGeneration/ ---
    QuestionGenerationController.php, DocumentParserService.php,
    PromptEngineeringService.php.

-   DocumentParserService.php: extracts text from PDFs via the
    smalot/pdfparser package and performs token-based chunking with
    overlap.

-   Laravel Queue System: each chunk\'s AI generation request is
    dispatched as a queued job (GenerateQuestionsJob) to avoid blocking
    the HTTP request thread.

-   PostgreSQL: new table ai_question_generation_jobs and extended
    QUESTION table (schema above).

-   AI Services Layer: a dedicated Python microservice proxies requests
    to the Anthropic API and performs JSON schema validation before
    returning results to the Laravel Service Layer.

[]{#heading_154 .anchor}**4.3 Novelty 3: Learning Gap Detection and
Recommendation Engine (LGD)**

[]{#heading_155 .anchor}**4.3.1 Problem Statement**

Current examination platforms return a single aggregate score that tells
a candidate whether they passed or failed but provides no actionable
guidance on which topics to revisit, at which cognitive depth, or in
which order. This absence of diagnostic feedback means that a failing
candidate cannot prioritize remediation efficiently, and that an
instructor cannot identify systematic gaps in cohort understanding.

[]{#heading_156 .anchor}**4.3.2 Research Contribution**

This novelty builds a post-exam analytics engine that maps each
incorrect or partially correct response to its question\'s topic tag,
Bloom\'s Taxonomy level, and difficulty band, then aggregates these
signals into per-topic mastery scores and a ranked Improvement Roadmap.
The engine produces both a personalized student-facing report and an
anonymized cohort-level gap heatmap for instructors, enabling
data-driven curriculum adjustment.

[]{#heading_157 .anchor}**4.3.3 Functional Requirements**

  -----------------------------------------------------------------------
  **Req. ID** **Functional / Quality Requirement**
  ----------- -----------------------------------------------------------
  FR-LGD-01   Topic Mastery Scoring: After exam grading completes, the
              LearningGapService shall compute a Topic Mastery Score
              (0--100) for each topic tag present in the exam by
              calculating the proportion of marks earned on items tagged
              to that topic, weighted by item difficulty.

  FR-LGD-02   Bloom\'s Taxonomy Weakness Profile: The service shall
              compute a Bloom\'s Level Accuracy Rate for each of the six
              taxonomy levels (Remember, Understand, Apply, Analyze,
              Evaluate, Create) based on items tagged at each level.

  FR-LGD-03   Difficulty-Level Weakness Analysis: The service shall
              compute accuracy rates separately for Easy, Medium, and
              Hard items to identify whether a candidate\'s weakness is
              difficulty-general or difficulty-specific.

  FR-LGD-04   Improvement Roadmap Generation: The service shall rank
              topics by mastery score (ascending) and produce a
              prioritized Improvement Roadmap listing the top 5 weakest
              topics, their Bloom\'s level breakdown, and a structured
              remediation suggestion per topic.

  FR-LGD-05   Personalized Learning Report: The candidate\'s dashboard
              shall display an interactive Learning Gap Report showing:
              Topic Mastery bar chart, Bloom\'s Radar chart, Difficulty
              Breakdown, and the ranked Improvement Roadmap.

  FR-LGD-06   Instructor Cohort Heatmap: Instructors shall access an
              aggregated, anonymized Cohort Gap Heatmap showing average
              Topic Mastery scores across all candidates in an exam
              cohort.

  FR-LGD-07   Automatic Trigger: The LearningGapService shall be
              triggered automatically by the Automated Grading Pipeline
              (FR-AG-04) upon final result publication; no manual
              instructor action shall be required to generate the report.

  FR-LGD-08   Report Persistence: Learning gap reports shall be stored in
              PostgreSQL and accessible to the candidate for the lifetime
              of their account. Historical reports across multiple exam
              attempts shall be retained and compared.
  -----------------------------------------------------------------------

[]{#heading_158 .anchor}**4.3.4 Non-Functional Requirements**

  ------------------------------------------------------------------------
  **Req. ID**  **Functional / Quality Requirement**
  ------------ -----------------------------------------------------------
  NFR-LGD-01   Performance: The full Learning Gap report for a 50-question
               exam shall be computed and written to the database within
               10 seconds of the grading pipeline completion trigger.

  NFR-LGD-02   Accuracy: Topic Mastery Score computation shall be
               deterministic; re-running the engine on the same result set
               shall produce identical scores.

  NFR-LGD-03   Cohort Privacy: The cohort heatmap shall display only
               aggregated, anonymized data; individual candidate scores
               shall not be inferable from the heatmap when the cohort
               size is below 10.
  ------------------------------------------------------------------------

[]{#heading_159 .anchor}**4.3.5 Database Modifications**

**Table: learning_gap_reports**

  -----------------------------------------------------------------------------------
  **Attribute**          **Data      **Key**   **References / Notes**
                         Type**                
  ---------------------- ----------- --------- --------------------------------------
  id                     UUID        PK        

  session_id             UUID        FK        exam_sessions.id

  candidate_id           UUID        FK        users.id

  exam_id                UUID        FK        exams.id

  topic_mastery_scores   JSONB                 { topic_tag: mastery_score } map

  bloom_accuracy         JSONB                 { bloom_level: accuracy_rate } map

  difficulty_accuracy    JSONB                 { Easy \| Medium \| Hard:
                                               accuracy_rate }

  improvement_roadmap    JSONB                 Ordered array of { topic, priority,
                                               bloom_gaps, suggestion }

  generated_at           TIMESTAMP             
  -----------------------------------------------------------------------------------

The existing QUESTION table is extended with: topic_tag VARCHAR(100);
bloom_level ENUM (Remember \| Understand \| Apply \| Analyze \| Evaluate
\| Create).

[]{#heading_160 .anchor}**4.3.6 REST API Design**

  ------------------------------------------------------------------------------------------------
  **Method**   **Endpoint**                          **Request**           **Response**
  ------------ ------------------------------------- --------------------- -----------------------
  GET          /api/learning/report/:session_id      Bearer JWT (Candidate { topic_mastery,
                                                     / Examiner)           bloom_accuracy,
                                                                           difficulty_accuracy,
                                                                           improvement_roadmap }

  GET          /api/learning/cohort/:exam_id         Bearer JWT (Examiner) { cohort_heatmap: {
                                                                           topic_tag: avg_mastery
                                                                           }\[\] }

  GET          /api/learning/history/:candidate_id   Bearer JWT            { reports: \[ {
                                                     (Candidate)           exam_id, session_id,
                                                                           generated_at, summary }
                                                                           \] }

  POST         /api/learning/trigger/:session_id     Bearer JWT (System    { status:
                                                     internal)             \'report_generated\',
                                                                           report_id }
  ------------------------------------------------------------------------------------------------

[]{#heading_161 .anchor}**4.3.7 Flutter Implementation Plan**

-   New Screen: LearningGapReportScreen --- displays topic mastery bar
    chart (fl_chart), Bloom\'s radar chart, difficulty accuracy tiles,
    and improvement roadmap list.

-   New BLoC: LearningGapBloc --- events: LoadReport, LoadHistory,
    LoadCohortHeatmap; states: LearningGapLoading, LearningGapLoaded,
    LearningGapError.

-   New Repository: LearningGapRepository --- fetches report from the
    Laravel API; caches last report in local SQLite for offline viewing.

-   Integration: ResultScreen gains a 'View Learning Report' action
    button that navigates to LearningGapReportScreen.

[]{#heading_162 .anchor}**4.3.8 Backend Implementation Plan**

-   Laravel Module: app/Modules/LearningGap/ ---
    LearningGapController.php, LearningGapService.php,
    RoadmapGenerator.php.

-   RoadmapGenerator.php: ranks topics ascending by mastery score and
    assembles the structured remediation suggestion per topic.

-   Laravel Queue System: LearningGapService is invoked via a queued
    listener attached to the GradingCompleted event fired by the
    Automated Grading Pipeline.

-   PostgreSQL: new table learning_gap_reports and extended QUESTION
    table (schema above); index on (exam_id, candidate_id).

[]{#heading_163 .anchor}**5. External Interface Requirements**

[]{#heading_164 .anchor}**5.1 User Interface**

The platform provides a consistent, responsive interface across all user
roles and form factors. The candidate portal delivers authentication
screens, exam interface panels, local timer widgets, network status
displays, and learning gap reports. The examiner portal renders question
builders including AI generation review screens, behavioral risk
dashboards, and learning gap cohort heatmaps. The invigilator interface
displays the live risk dashboard with per-candidate event streams and
action controls. The administrator panel summarizes platform statistics,
user management, and system health metrics.

[]{#heading_165 .anchor}**5.2 Hardware Interface**

The system integrates with biometric verification hardware (fingerprint
readers, Apple Face ID, Windows Hello) via native platform channel
wrappers. On desktop platforms, the kiosk module intercepts low-level
hardware keyboard input to block system shortcuts. The behavioral
telemetry service has no special hardware requirements beyond the
baseline device specifications in Section 2.4. The AI question
generation service is hardware-agnostic but benefits from
GPU-accelerated inference on server infrastructure.

[]{#heading_166 .anchor}**5.3 Software Interface**

-   **Central Backend REST Interface**: Structured HTTPS endpoints using
    JSON data frames over TLS 1.3, served by the PHP Laravel API
    Backend.

-   **AI API Interface**: Anthropic Messages API (claude-sonnet-4-6
    model) over HTTPS via the Python AI Service; falls back to
    manual-only mode if unavailable.

-   **Remote Message Relay**: FCM SDK for push notifications across
    mobile and web; native OS daemon APIs for desktop.

-   **Local Relational Storage**: sqflite plugin (mobile) and
    sqflite_common_ffi (desktop) with SQLCipher encryption.

-   **Credentials Manager**: flutter_secure_storage for JWT isolation.

-   **Network Monitor**: connectivity_plus for connection state changes.

-   **Server-Sent Events**: dart:html EventSource (web) and http_parser
    (native) for InvigilatorDashboard real-time updates.

-   **PDF Generation**: barryvdh/laravel-dompdf (Laravel backend) for
    institutional report exports; pdf package (Flutter client) for local
    export.

-   **Code Execution Sandbox**: Docker Code Execution Service, invoked
    by the Laravel Service Layer for code-frame grading (FR-AG-03).

[]{#heading_167 .anchor}**5.4 Communication Interface**

All communication uses HTTPS over TLS 1.3. During offline exam sessions
the network layer buffers all pending requests locally and resumes
transmission upon connectivity restoration. The InvigilatorDashboard
uses Server-Sent Events (SSE) for near-real-time risk score delivery;
SSE is preferred over WebSocket to avoid persistent connection overhead.

[]{#heading_168 .anchor}**6. System Models, UML Diagrams, and
Architecture**

[]{#heading_169 .anchor}**6.1 System Use Case Summary Diagram**

The unified use-case framework retains the baseline actors (Candidate,
Examiner, Institutional Administrator, System Administrator) and adds a
Live Invigilator actor and an AI Engine external actor. New use cases
added by the novelty modules include: UC-15 Take Behavior-Monitored Exam
(Candidate), UC-16 View Behavioral Risk Dashboard (Live Invigilator),
UC-17 Generate Questions from Syllabus (Examiner → AI Engine), UC-18
Approve AI Questions (Examiner), UC-19 View Learning Gap Report
(Candidate), UC-20 View Cohort Heatmap (Examiner), UC-21 Review
Generation Job (Examiner → AI Engine).

![FSEP System Use Case
Diagram](media/771de2f4d2084a61cf117d9b6e7d4ba3f1f88334.png "FSEP System Use Case Diagram"){width="6.041666666666667in"
height="3.7291666666666665in"}

*Figure 6.1 --- FSEP System Use Case Diagram*

[]{#heading_170 .anchor}**6.2 Updated Technical Domain Class Diagram**

The class diagram adds the following classes to the existing domain
model: BehavioralTelemetryService (+captureEvent(),
+computeRiskScore()), RiskScore (+score: Int, +band: RiskBandEnum),
BehavioralEvent (+eventType: Enum, +severity: Enum),
QuestionGenerationJob (+status: JobStatusEnum, +dispatchPrompts(),
+parseResponse()), Question (+isAiGenerated: Boolean, +reviewStatus:
Enum), ReviewAction (+action: Enum, +note: String), LearningGapReport
(+topicMastery: Map, +bloomAccuracy: Map, +generateRoadmap()).

![Updated Technical Domain Class
Diagram](media/fcea9ea4786771462fd63e6529825c05902fb532.png "Updated Technical Domain Class Diagram"){width="6.041666666666667in"
height="3.8020833333333335in"}

*Figure 6.2 --- Updated Technical Domain Class Diagram*

[]{#heading_171 .anchor}**6.3 Behavior-Monitored Exam Session Sequence
Diagram**

The sequence diagram describes the baseline exam session lifecycle
extended with behavioral telemetry: (a) on session start, the Behavioral
Service initializes a telemetry session; (b)
BehavioralTelemetryService.captureEvent() fires on every user
interaction in parallel with normal answer submission; (c) the
Behavioral Service computes a running Risk Score after each submitted
answer; (d) upon exam submission,
BehavioralIntegrityService.finalizeRiskScore() is called before result
processing; (e) post-grading, LearningGapService.generateReport() is
invoked automatically and its link is included in the final result
notification.

![Behavior-Monitored Exam Session Sequence
Diagram](media/86bf2c857e2ac3611c7aa17fb80d0a8981c80cb2.png "Behavior-Monitored Exam Session Sequence Diagram"){width="5.625in"
height="3.5in"}

*Figure 6.3 --- Behavior-Monitored Exam Session Sequence Diagram*

[]{#heading_172 .anchor}**6.4 Learning Gap Detection Post-Exam Activity
Diagram**

The post-exam activity flow: Grading Pipeline completes →
LearningGapService.computeTopicMastery() → computeBloomAccuracy() →
computeDifficultyAccuracy() (Easy / Medium / Hard) → generateRoadmap() →
persist LearningGapReport → send FCM push notification containing the
score and the Learning Gap Report link.

![Learning Gap Detection Post-Exam Activity
Diagram](media/4bbb1ff404f8aca8e2a085bac56fc56921021e61.png "Learning Gap Detection Post-Exam Activity Diagram"){width="4.75in"
height="4.0in"}

*Figure 6.4 --- Learning Gap Detection Post-Exam Activity Diagram*

[]{#heading_173 .anchor}**6.5 Integrated System Architecture**

The full FSEP architecture with novelties integrates the following
layers: Flutter Client (BLoC modules: BehavioralBloc,
QuestionGenerationBloc, LearningGapBloc; Services:
BehavioralTelemetryService, DocumentParserService); Local Storage
(SQLite + SQLCipher: tables for behavioral_events and offline exam
data); PHP Laravel Backend (modules: Behavioral Service, Question
Generation Service, Learning Gap Service, all exposed via a unified
Laravel REST API and Laravel Queue System); AI Services Layer (Python AI
Service proxying the Anthropic API with prompt engineering templates and
JSON schema validation); PostgreSQL (all tables defined in Sections
4.1--4.3); Docker Code Execution Service (sandboxed grading for
code-frame responses); Firebase Cloud Messaging (push notification
delivery).

![Integrated FSEP System
Architecture](media/8a1763d7d8893dfc07839d471a3c11292a51f7d6.png "Integrated FSEP System Architecture"){width="6.041666666666667in"
height="2.84375in"}

*Figure 6.5 --- Integrated FSEP System Architecture*

[]{#heading_174 .anchor}**6.6 Database Entity Relationship Diagram
(ERD)**

The extended ERD retains the original entities (INSTITUTION, USER, EXAM,
QUESTION_BANK, QUESTION, EXAM_SESSION, ANSWER, PROCTOR_LOG, RESULT) and
adds: BEHAVIORAL_EVENTS (FK to EXAM_SESSION and USER),
BEHAVIORAL_RISK_SCORES (FK to EXAM_SESSION), BEHAVIORAL_REVIEW_ACTIONS
(FK to BEHAVIORAL_EVENTS and USER), AI_QUESTION_GENERATION_JOBS (FK to
USER), LEARNING_GAP_REPORTS (FK to EXAM_SESSION, USER, EXAM).

![FSEP Extended Database Entity Relationship
Diagram](media/9a5501c0f0f46542426d8d2c1379b2751b45024a.png "FSEP Extended Database Entity Relationship Diagram"){width="6.041666666666667in"
height="3.6041666666666665in"}

*Figure 6.6 --- FSEP Extended Database Entity Relationship Diagram*

[]{#heading_175 .anchor}**7. Non-Functional Requirements**

Non-functional requirements define the quality attributes and
operational constraints of the system across all modules including the
three novelty extensions.

  ----------------------------------------------------------------------------
  **Category**      **Requirement Detail**
  ----------------- ----------------------------------------------------------
  Performance       Application cold boot ≤ 3 s on mid-range Android. Single
                    question fetch from SQLite ≤ 200 ms. 100-item sync bundle
                    ≤ 10 s on 4G. Server P95 response ≤ 500 ms under 5,000
                    concurrent sessions via the Laravel REST API. Risk score
                    recompute ≤ 200 ms server-side. Learning gap report
                    generation ≤ 10 s.

  Security          All communications over HTTPS/TLS 1.3 with SSL certificate
                    pinning on mobile. JWT stored in flutter_secure_storage.
                    SQLite encrypted via SQLCipher AES-256. Behavioral
                    telemetry AES-256 at rest on server. OWASP MASVS Level 1
                    (candidate) and Level 2 (admin) compliance. GDPR-aligned
                    behavioral data retention ≤ 90 days.

  Reliability       Offline autonomy ≤ 72 continuous hours. Server SLA 99.9%
                    monthly uptime. Zero data-loss on crash via synchronous
                    SQLite writes. Exponential backoff sync retry (1 s, 2 s, 4
                    s, 8 s; cap 5 attempts). AI API unavailability degrades
                    gracefully to manual-only question authoring.

  Scalability       Kubernetes auto-scale on CPU ≥ 70% for the Laravel API
                    Backend and the Python AI Service. Local SQLite supports
                    10,000 questions and 500 interaction logs without latency
                    degradation. Notification manager supports 100,000
                    concurrent device tokens.

  Usability         SUS score ≥ 70 across all platform editions. First-time
                    candidate completes mock exam within 5 minutes unaided.
                    Full WCAG 2.1 AA accessibility. Text scaling to 200%
                    without layout breakage. Full dark mode support
                    auto-synced to OS preference.

  Maintainability   Minimum 80% unit and widget test coverage enforced via
                    CI/CD. All public methods documented with dartdoc
                    (Flutter) and phpdoc (Laravel). Semantic Versioning
                    (SemVer) for all releases. Each novelty module deployable
                    and upgradeable independently without redeploying
                    unrelated Laravel modules.

  Accuracy          Risk score false positive rate ≤ 10% on known-clean
                    sessions. Topic mastery score computation deterministic
                    across reruns.
  ----------------------------------------------------------------------------

[]{#heading_176 .anchor}**8. Conclusion**

The Flutter Smart Examination Portal, as specified in this document,
represents a comprehensive, research-grade contribution to institutional
assessment technology. By extending a robust offline-first,
cross-platform, kiosk-secured examination baseline with three deeply
integrated novelty modules --- Behavioral Cheating Detection, AI
Question Generation, and Learning Gap Detection --- the system addresses
three concrete and well-established gaps in the state of the art that no
commercially available or open-source platform currently resolves within
a single unified ecosystem.

A comparative review of ExamSoft, Moodle with Safe Exam Browser, and
Google Forms confirms that each platform addresses a subset of these
needs but leaves the remaining gaps unresolved. FSEP uniquely satisfies
all three research contributions within a self-hosted, offline-capable,
natively cross-platform architecture built on a PHP Laravel backend,
establishing clear academic, practical, and publication significance.

This Software Requirement Specification has formally defined the
complete scope of the system in accordance with IEEE Std 830-1998 and
ISO/IEC/IEEE 29148:2018. The functional requirements in Section 3 and
Section 4 specify every capability the platform must deliver. The
non-functional requirements in Section 7 establish the measurable
quality standards governing performance, security, reliability,
scalability, and accuracy. The architecture and UML models in Section 6
provide both structural and behavioral models of the integrated system.
The appendices supply supporting reference material including the
consolidated API reference, test case traceability, bibliography, and
revision history.

This document provides the complete technical baseline for the
subsequent phases of design, implementation, testing, and academic
evaluation of the Flutter Smart Examination Portal.

[]{#heading_177 .anchor}**Appendix A: Glossary of Additional Terms**

  -----------------------------------------------------------------------
  **Term**         **Definition**
  ---------------- ------------------------------------------------------
  FSEP             Flutter Smart Examination Portal --- the system
                   defined by this SRS.

  JWT              JSON Web Token --- a cryptographically signed
                   stateless authorization credential.

  RBAC             Role-Based Access Control.

  MFA              Multi-Factor Authentication via hardware biometric or
                   TOTP token.

  BLoC             Business Logic Component --- Flutter state management
                   pattern.

  SQLite           Lightweight relational database used for on-device
                   offline storage.

  SQLCipher        AES-256 transparent encryption extension for SQLite.

  FCM              Firebase Cloud Messaging --- cross-platform push
                   notification protocol.

  Risk Score       A 0--100 composite behavioral integrity score produced
                   by the Behavioral Cheating Detection System.

  Bloom\'s         Hierarchical cognitive classification: Remember,
  Taxonomy         Understand, Apply, Analyze, Evaluate, Create.

  SSE              Server-Sent Events --- a unidirectional HTTP streaming
                   protocol used for the live invigilator dashboard.

  Docker           Containerization platform used to sandbox
                   code-execution grading environments.

  GDPR             General Data Protection Regulation --- EU privacy
                   regulation governing personal data retention.

  OWASP MASVS      Open Web Application Security Project Mobile
                   Application Security Verification Standard.

  TLS              Transport Layer Security --- cryptographic protocol
                   for network communication; version 1.3 required.

  ERD              Entity Relationship Diagram.

  SLA              Service Level Agreement --- contractual
                   availability/performance commitment.

  SUS              System Usability Scale --- standardized 10-item
                   usability questionnaire.

  Laravel          PHP web application framework providing the REST API,
                   service layer, and queue system for the FSEP backend.

  Laravel Queue    Asynchronous job-processing subsystem used for AI
  System           generation and risk-score recomputation tasks.
  -----------------------------------------------------------------------

[]{#heading_178 .anchor}**Appendix B: Consolidated API Endpoint
Reference**

Baseline endpoints (Section 3 modules), served by the PHP Laravel REST
API:

  ------------------------------------------------------------------------------
  **Method**   **Endpoint**          **Request**           **Response**
  ------------ --------------------- --------------------- ---------------------
  POST         /api/auth/login       { email, password }   { jwt_token, role,
                                                           user_id }

  POST         /api/auth/register    { name, email,        { user_id, status }
                                     password, role }      

  GET          /api/users/profile    Bearer JWT            { user profile object
                                                           }

  PUT          /api/users/profile    Bearer JWT + profile  { updated profile }
                                     fields                

  GET          /api/exams            Bearer JWT            { exams\[\] }

  POST         /api/exams            Bearer JWT            { exam_id }
                                     (Examiner) + exam     
                                     config                

  GET          /api/questions        Bearer JWT            { questions\[\] }

  POST         /api/questions        Bearer JWT            { question_id }
                                     (Examiner) + question 
                                     data                  

  POST         /api/submissions      Bearer JWT            { submission_id,
                                     (Candidate) +         score }
                                     answers\[\]           

  GET          /api/results          Bearer JWT            { results\[\] }

  POST         /api/sync             Bearer JWT +          { synced_count }
                                     offline_data\[\]      
  ------------------------------------------------------------------------------

Novelty module endpoints: see Sections 4.1.8 (Behavioral Cheating
Detection), 4.2.8 (Question Generation), and 4.3.6 (Learning Gap
Detection) for full API tables.

[]{#heading_179 .anchor}**Appendix C: Test Case Traceability Matrix**

  -----------------------------------------------------------------------
  **Requirement ID /     **Description**
  Test Case ID**         
  ---------------------- ------------------------------------------------
  FR-UM-01 / TC-001      User Registration

  FR-UM-02 / TC-002      JWT Authentication

  FR-UM-03 / TC-003      Role Authorization (RBAC)

  FR-EA-01 / TC-004      Exam Creation and Configuration

  FR-QM-01 / TC-005      Multi-Format Question Authoring

  FR-ED-01 / TC-006      Offline Exam Execution

  FR-ED-03 / TC-007      Session State Recovery

  FR-AG-01 / TC-008      Auto Grading (MCQ / True-False)

  FR-RA-01 / TC-009      Score Reporting and Dashboard

  FR-PN-01 / TC-010      Push Notification Delivery

  FR-BCD-01 / TC-011     Behavioral Event Capture

  FR-BCD-02 / TC-012     Risk Score Computation

  FR-BCD-04 / TC-013     Live Invigilator Dashboard Update

  FR-BCD-05 / TC-014     Alert Generation on Risk Threshold Breach

  FR-QG-01 / TC-015      Document Upload for AI Generation

  FR-QG-05 / TC-016      PENDING_REVIEW Quarantine Gate

  FR-QG-06 / TC-017      Examiner Approval Workflow

  FR-LGD-01 / TC-018     Topic Mastery Score Computation

  FR-LGD-02 / TC-019     Bloom\'s Taxonomy Weakness Profile

  FR-LGD-04 / TC-020     Improvement Roadmap Generation
  -----------------------------------------------------------------------

[]{#heading_180 .anchor}**Appendix D: Bibliography and References**

[]{#heading_181 .anchor}**D.1 Standards and Guidelines**

IEEE Std 830-1998 --- IEEE Recommended Practice for Software
Requirements Specifications. IEEE, New York, USA.

ISO/IEC/IEEE 29148:2018 --- Systems and Software Engineering:
Requirements Engineering. ISO, Geneva.

OWASP Mobile Application Security Verification Standard (MASVS). OWASP
Foundation.

GDPR 2016/679 --- General Data Protection Regulation. European Union.

[]{#heading_182 .anchor}**D.2 Technical Documentation**

Google LLC. (2024). Flutter Framework Documentation.
https://docs.flutter.dev.

Google LLC. (2024). Firebase Cloud Messaging Documentation.
https://firebase.google.com/docs.

Zetetic LLC. (2024). SQLCipher Documentation.
https://www.zetetic.net/sqlcipher.

Anthropic PBC. (2024). Claude API Documentation.
https://docs.anthropic.com.

The PostgreSQL Global Development Group. (2024). PostgreSQL 15
Documentation. https://www.postgresql.org/docs/15.

Laravel LLC. (2024). Laravel 11 Documentation. https://laravel.com/docs.

[]{#heading_183 .anchor}**D.3 Research References**

Anderson, L. W., & Krathwohl, D. R. (2001). A Taxonomy for Learning,
Teaching, and Assessing. Longman.

Bloom, B. S. (1956). Taxonomy of Educational Objectives: The
Classification of Educational Goals. David McKay Company.

Romero, C., & Ventura, S. (2020). Educational Data Mining and Learning
Analytics: An Updated Survey. Wiley Interdisciplinary Reviews: Data
Mining and Knowledge Discovery.

[]{#heading_184 .anchor}**Appendix E: Document Revision History**

  -----------------------------------------------------------------------
  **Version**   **Description of Change**
  ------------- ---------------------------------------------------------
  v1.0 ---      Ubaidullah, Faisal Ahmad, M. Asad Malik
  Original      

  v2.0          Ubaidullah, Faisal Ahmad, M. Asad Malik --- full document
                rebuild with corrected heading/body typography, working
                Table of Contents, and complete UML/ER diagram set
                (Section 6).

  v3.0          Ubaidullah, Faisal Ahmad, M. Asad Malik --- backend
                migrated from Node.js/Express to PHP Laravel throughout;
                AI Adaptive Examination Engine (Novelty 1) and
                Blockchain-Based Result Verification (Novelty 5) removed
                in full; remaining novelties renumbered to Behavioral
                Cheating Detection (1), AI Question Generator (2), and
                Learning Gap Detection (3); Section 2.2 retitled
                'Metadata'; technical stack, UML diagrams, ERD, and API
                references updated for consistency.

  v4.0 ---      Ubaidullah, Faisal Ahmad, M. Asad Malik --- Section 2.2
  Current       (Metadata: comparative platform analysis of ExamSoft,
                Moodle + SEB, and Google Forms) extracted into a separate
                standalone document; remaining Section 2 subsections
                renumbered (2.3--2.8 shifted to 2.2--2.7); internal
                cross-references updated accordingly.
  -----------------------------------------------------------------------
