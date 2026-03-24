// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"
import { createConsumer } from "@rails/actioncable"
import "./confirm_modal"
import "./delete_choice_modal"
import "./resource_tags"
import "./sidebar_collapse"

Turbo.session.connectStreamSource(createConsumer())
