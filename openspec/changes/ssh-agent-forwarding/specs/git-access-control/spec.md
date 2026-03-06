## MODIFIED Requirements

### Requirement: Git access control prompt
The interactive Git access prompt SHALL continue to offer the same 5 choices but SHALL skip the SSH key selection UI when agent forwarding is active.

#### Scenario: Agent forwarding active skips key selection
- **GIVEN** SSH agent socket is detected on the host
- **WHEN** the user selects Git access option 1, 2, 4, or 5
- **THEN** the system SHALL skip the SSH key selection UI
- **AND** the system SHALL inform the user that SSH agent forwarding is being used
- **AND** the system SHALL still save the workspace preference for future sessions
