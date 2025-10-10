class RenameActivationStateToActivationStatusInOrganizations < ActiveRecord::Migration[7.2]
  def change
    rename_column :organizations, :activation_state, :activation_status
  end
end
