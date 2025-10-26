# PaperCraft

PaperCraft is a comprehensive Flutter-based application for managing question papers and assessments. It provides teachers and administrators with tools to create, review, and manage question papers efficiently.

## Features

- **Paper Creation & Management** - Create and manage question papers with support for various question types
- **Question Bank** - Organize and search through a comprehensive question database
- **Paper Review** - Collaborative review process with feedback and approval workflows
- **Assignment Management** - Assign papers to students and track submissions
- **Admin Dashboard** - Monitor system metrics and manage users
- **PDF Generation** - Generate professional PDF reports and question papers
- **User Authentication** - Secure login and role-based access control
- **Real-time Updates** - Live synchronization across multiple devices

## Architecture

The application follows Clean Architecture principles with Clear separation of concerns:
- **Domain Layer** - Business logic and entities
- **Data Layer** - Repository implementations and data sources
- **Presentation Layer** - UI components and BLoC state management

## Project Structure

```
lib/
├── core/                 # Core utilities, theme, and configuration
├── features/             # Feature-specific modules
│   ├── authentication/   # User login and auth
│   ├── home/            # Main dashboard
│   ├── paper_workflow/  # Paper creation and management
│   ├── paper_review/    # Review process
│   ├── assignments/     # Assignment management
│   ├── admin/           # Admin features
│   └── pdf_generation/  # PDF export functionality
└── main.dart           # Application entry point
```

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```

## Testing

Run the test suite:
```bash
flutter test
```

For detailed testing guide, see [TESTING_GUIDE.md](TESTING_GUIDE.md)

## Documentation

- [Testing Guide](TESTING_GUIDE.md) - Unit and widget testing procedures
- [Refactoring Plan](REFACTORING_PLAN.md) - Architecture improvements
- [AI Implementation](documentation/ai_implementation.md) - AI features overview
- [BLoC Migration Guide](documentation/BLOC_SEPARATION_MIGRATION_GUIDE.md) - State management refactoring

## Technologies

- **Flutter** - Cross-platform UI framework
- **Dart** - Programming language
- **BLoC** - State management
- **GetIt** - Dependency injection
- **Supabase** - Backend and database
- **PDF** - PDF generation library

## License

This project is proprietary and confidential.
