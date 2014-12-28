require_dependency 'repositories_controller'

module RedmineGitHosting
  module Patches
    module RepositoriesControllerPatch

      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable

          alias_method_chain :show,    :git_hosting
          alias_method_chain :create,  :git_hosting
          alias_method_chain :update,  :git_hosting
          alias_method_chain :destroy, :git_hosting

          before_filter :set_current_tab, only: :edit

          helper :git_hosting

          # Load ExtendRepositoriesHelper so we can call our
          # additional methods.
          helper :extend_repositories
        end
      end


      module InstanceMethods

        def show_with_git_hosting(&block)
          if @repository.is_a?(Repository::Xitolite) && @repository.empty?
            # Fake list of repos
            @repositories = @project.gitolite_repos
            render 'git_instructions'
          else
            show_without_git_hosting(&block)
          end
        end


        def create_with_git_hosting(&block)
          create_without_git_hosting(&block)
          call_use_cases
        end


        def update_with_git_hosting(&block)
          update_without_git_hosting(&block)
          call_use_cases
        end


        def destroy_with_git_hosting(&block)
          destroy_without_git_hosting(&block)
          call_use_cases
        end


        private


          def set_current_tab
            @tab = params[:tab] || ""
          end


          def call_use_cases
            if @repository.is_a?(Repository::Xitolite)
              if !@repository.errors.any?
                case self.action_name
                when 'create'
                  set_repository_extras
                  CreateRepository.new(@repository, creation_options).call
                when 'update'
                  UpdateRepository.new(@repository).call
                when 'destroy'
                  DestroyRepository.new(@repository.data_for_destruction, destroy_options).call
                end
              end
            end
          end


          def set_repository_extras
            extra = @repository.build_git_extra(default_extra_options)
            extra.save!
          end


          def creation_options
            {create_readme_file: create_readme_file?, enable_git_annex: enable_git_annex?}
          end


          def create_readme_file?
            @repository.create_readme == 'true' ? true : false
          end


          def enable_git_annex?
            @repository.enable_git_annex == 'true' ? true : false
          end


          def destroy_options
            {message: "User '#{User.current.login}' has removed repository '#{@repository.gitolite_repository_name}'"}
          end


          def default_extra_options
            enable_git_annex? ? git_annex_repository_options : standard_repository_options
          end


          def standard_repository_options
            {
              git_http:       RedmineGitHosting::Config.get_setting(:gitolite_http_by_default),
              git_daemon:     RedmineGitHosting::Config.get_setting(:gitolite_daemon_by_default, true),
              git_notify:     RedmineGitHosting::Config.get_setting(:gitolite_notify_by_default, true),
              git_annex:      false,
              default_branch: 'master',
              key:            RedmineGitHosting::Utils.generate_secret(64)
            }
          end


          def git_annex_repository_options
            {
              git_http:       0,
              git_daemon:     false,
              git_notify:     false,
              git_annex:      true,
              default_branch: 'git-annex',
              key:            RedmineGitHosting::Utils.generate_secret(64)
            }
          end

      end

    end
  end
end

unless RepositoriesController.included_modules.include?(RedmineGitHosting::Patches::RepositoriesControllerPatch)
  RepositoriesController.send(:include, RedmineGitHosting::Patches::RepositoriesControllerPatch)
end
