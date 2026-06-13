require "spec_helper"

RSpec.describe Crimson::SkillRouter do
  let(:skills_dir) { File.expand_path("../../skills", __dir__) }
  subject(:router) { described_class.new(skills_dirs: [skills_dir]) }

  describe "#resolve" do
    it "always includes coding skill" do
      result = router.resolve("hello")
      expect(result).to include("coding")
    end

    it "loads git skill for commit messages" do
      result = router.resolve("commit my changes")
      expect(result).to include("git")
    end

    it "loads debugging skill for bug messages" do
      result = router.resolve("fix the bug in parser")
      expect(result).to include("debugging")
    end

    it "loads research skill for analysis questions" do
      result = router.resolve("how does the parser work")
      expect(result).to include("research")
    end

    it "loads testing skill for test messages" do
      result = router.resolve("write a test for this")
      expect(result).to include("testing")
    end

    it "loads writing skill for doc messages" do
      result = router.resolve("update the readme")
      expect(result).to include("writing")
    end

    it "loads planning skill for design messages" do
      result = router.resolve("plan a new feature architecture")
      expect(result).to include("planning")
    end

    it "loads refactoring skill for refactor messages" do
      result = router.resolve("refactor this method")
      expect(result).to include("refactoring")
    end

    it "loads review skill for code review messages" do
      result = router.resolve("review this code quality")
      expect(result).to include("review")
    end

    it "handles British spelling (analyse)" do
      result = router.resolve("analyse this codebase")
      expect(result).to include("research")
    end

    it "handles American spelling (analyze)" do
      result = router.resolve("analyze this codebase")
      expect(result).to include("research")
    end

    it "limits to max 2 conditional skills plus coding" do
      result = router.resolve("fix the bug, commit the changes, write a test, refactor the code")
      non_coding = result - ["coding"]
      expect(non_coding.length).to be <= 2
    end

    it "returns only string types" do
      result = router.resolve("commit my changes")
      expect(result).to all(be_a(String))
    end

    it "uses word boundaries for single-word triggers" do
      result = router.resolve("explain the situation")
      expect(result).to include("research")
    end
  end

  describe "#resolve with auto_inject" do
    it "injects security skill when write_file is used" do
      result = router.resolve("fix a bug", tools_invoked: ["write_file"])
      expect(result).to include("security")
    end

    it "injects security skill when edit_file is used" do
      result = router.resolve("hello world", tools_invoked: ["edit_file"])
      expect(result).to include("security")
    end

    it "does not inject security skill for read-only tools" do
      result = router.resolve("hello world", tools_invoked: ["read_file"])
      expect(result).not_to include("security")
    end

    it "adds security on top of matched skills" do
      result = router.resolve("fix the bug", tools_invoked: ["write_file"])
      expect(result).to include("coding", "debugging", "security")
    end
  end

  describe "#load_skill" do
    it "loads skill content by name" do
      content = router.load_skill("git")
      expect(content).to include("Git workflow")
    end

    it "strips YAML front-matter from content" do
      content = router.load_skill("coding")
      expect(content).not_to start_with("---")
      expect(content).to include("Crimson")
    end

    it "returns nil for unknown skill" do
      expect(router.load_skill("nonexistent_skill")).to be_nil
    end
  end

  describe "#skill_names" do
    it "returns all skill names as strings" do
      names = router.skill_names
      expect(names).to include("coding", "git", "debugging", "testing", "refactoring")
      expect(names).to include("research", "review", "writing", "planning", "security")
    end
  end
end
